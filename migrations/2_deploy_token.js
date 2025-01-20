const Token = artifacts.require("Token");

module.exports = async function (deployer, network, accounts) {
  // The deployer will deploy the Token contract
  await deployer.deploy(Token);

  // Retrieve the deployed instance of the Token contract
  const tokenInstance = await Token.deployed();

  console.log("Token deployed successfully!");
  console.log("Contract Address:", tokenInstance.address);
};
