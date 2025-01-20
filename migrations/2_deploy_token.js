const Token = artifacts.require("Token");

module.exports = async function (deployer) {
    console.log("Starting deployment...");
    await deployer.deploy(Token);
    console.log("Token deployed!");
};
