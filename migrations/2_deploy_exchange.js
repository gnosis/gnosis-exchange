var Exchange = artifacts.require("./Exchange.sol"),
    Arithmetic = artifacts.require("./Arithmetic.sol");

module.exports = function(deployer) {
    deployer.deploy(Arithmetic);
    deployer.link(Arithmetic, Exchange);
    deployer.deploy(Exchange);
};
