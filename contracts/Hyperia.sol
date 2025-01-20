// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

 

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
  constructor() ERC20("Hyperia","HYP"){
      uint256 totalSupply = 4_000_000_000 * (10 ** decimals());
              _mint(msg.sender, totalSupply);
  }

}