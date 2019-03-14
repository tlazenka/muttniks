const Adoption = artifacts.require("Adoption");

module.exports = function(deployer, network, accounts) {
    const account = accounts[0];

    deployer.then(async() => {
        let adoption = await Adoption.deployed();
        await adoption.createAdoptee(1, { from: account });
        await adoption.createAdoptee(2, { from: account });
        await adoption.createAdoptee(3, { from: account });
        await adoption.createAdoptee(4, { from: account });
        await adoption.createAdoptee(5, { from: account });
        await adoption.createAdoptee(6, { from: account });
    });
};
