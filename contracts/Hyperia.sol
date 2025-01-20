// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ServiceToken is ERC20, Ownable {
    uint256 public transactionFeePercentage;  
    uint256 public burnPercentage;  
    address public feeReceiver;  

     mapping(address => uint256) public stakes;
    mapping(address => uint256) public rewardBalances;
    uint256 public rewardRatePerBlock; // Reward rate for staking
    mapping(address => uint256) public lastStakedBlock;

     struct Escrow {
        address client;
        address provider;
        uint256 amount;
        bool completed;
        bool refunded;
        bool clientAgreed;
        bool providerAgreed;
    }
    mapping(uint256 => Escrow) public escrows;
    uint256 public escrowCounter;

     event ParametersUpdated(uint256 feePercentage, uint256 burnPercentage, address owner);
    event Staked(address indexed staker, uint256 amount);
    event Unstaked(address indexed staker, uint256 amount, uint256 rewards);
    event ServicePayment(address indexed client, address indexed provider, uint256 amount);
    event EscrowCreated(uint256 indexed escrowId, address indexed client, address indexed provider, uint256 amount);
    event EscrowCompleted(uint256 indexed escrowId);
    event EscrowRefunded(uint256 indexed escrowId);

 constructor() ERC20("Hyperia", "HYP") Ownable() {
    uint256 MAX_SUPPLY = 4_000_000_000 * (10 ** decimals());
    _mint(msg.sender, MAX_SUPPLY);
    transactionFeePercentage = 2; 
    burnPercentage = 1; 
    feeReceiver = msg.sender;  
    rewardRatePerBlock = 1e18;  
}


    function updateParameters(uint256 _transactionFeePercentage, uint256 _burnPercentage, address _feeReceiver) external onlyOwner {
        require(_transactionFeePercentage <= 10, "Fee too high");
        require(_burnPercentage <= 10, "Burn too high");
        require(_feeReceiver != address(0), "Invalid owner address");

        transactionFeePercentage = _transactionFeePercentage;
        burnPercentage = _burnPercentage;
        feeReceiver = _feeReceiver;

        emit ParametersUpdated(_transactionFeePercentage, _burnPercentage, _feeReceiver);
    }

    function payForService(address serviceProvider, uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _transfer(msg.sender, serviceProvider, amount);
        emit ServicePayment(msg.sender, serviceProvider, amount);
    }

     function createEscrow(address serviceProvider, uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _transfer(msg.sender, address(this), amount);

        escrows[escrowCounter] = Escrow({
            client: msg.sender,
            provider: serviceProvider,
            amount: amount,
            completed: false,
            refunded: false,
            clientAgreed: false,
            providerAgreed: false
        });

        emit EscrowCreated(escrowCounter, msg.sender, provider, amount);
        escrowCounter++;
    }

    function completeEscrow(uint256 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        require(!escrow.completed, "Escrow already completed");
        require(!escrow.refunded, "Escrow already refunded");
        require(escrow.client == msg.sender, "Only the client can complete the escrow");

        _transfer(address(this), escrow.provider, escrow.amount);
        escrow.completed = true;

        emit EscrowCompleted(escrowId);
    }

    function refundEscrow(uint256 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        require(!escrow.completed, "Escrow already completed");
        require(!escrow.refunded, "Escrow already refunded");
        require(
            msg.sender == escrow.client || msg.sender == escrow.provider,
            "Only client or provider can request a refund"
        );

         if (msg.sender == escrow.client) {
            escrow.clientAgreed = true;
        } else if (msg.sender == escrow.provider) {
            escrow.providerAgreed = true;
        }

        if (escrow.clientAgreed && escrow.providerAgreed) {
            _transfer(address(this), escrow.client, escrow.amount);
            escrow.refunded = true;
            escrow.clientAgreed = false;
            escrow.providerAgreed = false;

            emit EscrowRefunded(escrowId);
        }
    }

     function stake(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        _transfer(msg.sender, address(this), amount);
        _updateRewards(msg.sender);

        stakes[msg.sender] += amount;
        lastStakedBlock[msg.sender] = block.number;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(stakes[msg.sender] >= amount, "Insufficient staked balance");

        _updateRewards(msg.sender);
        stakes[msg.sender] -= amount;

        _transfer(address(this), msg.sender, amount + rewardBalances[msg.sender]);
        rewardBalances[msg.sender] = 0;

        emit Unstaked(msg.sender, amount, rewardBalances[msg.sender]);
    }

    function _updateRewards(address staker) internal {
        if (lastStakedBlock[staker] > 0) {
            uint256 blocks = block.number - lastStakedBlock[staker];
            rewardBalances[staker] += (stakes[staker] * blocks * rewardRatePerBlock) / 1e18;
        }
        lastStakedBlock[staker] = block.number;
    }

   function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
    if (from != address(0) && to != address(0)) { // Ignore mint and burn
        uint256 feeAmount = (amount * transactionFeePercentage) / 100;
        uint256 burnAmount = (amount * burnPercentage) / 100;
        uint256 totalDeductions = feeAmount + burnAmount;

        require(amount > totalDeductions, "Amount too small for fees");

        if (feeAmount > 0) {
            super._transfer(from, feeReceiver, feeAmount);
        }
        if (burnAmount > 0) {
            _burn(from, burnAmount);
        }
    }
}

}
