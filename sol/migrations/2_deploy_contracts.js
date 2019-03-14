const Adoption = artifacts.require("Adoption");

module.exports = function(deployer, network, accounts) {
    deployer.then(async() => {
        await deployer.deploy(Adoption);
    });
};
