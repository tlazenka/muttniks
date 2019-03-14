const truffleAssert = require('truffle-assertions');
const Adoption = artifacts.require("Adoption");

contract("Adoption", async accounts => {

    let instance;

    beforeEach(async function () {
        instance = await Adoption.new();
    });

    it("should allow adoption and naming", async () => {

        await instance.createAdoptee(0, { from: accounts[0] });
        assert.equal(false, await instance.isAdopted(0));
        await instance.createAdoptee(1, { from: accounts[0] });
        assert.equal(false, await instance.isAdopted(1));
        await instance.adopt(0, { from: accounts[0] });
        assert.equal(accounts[0], await instance.adopterOf(0));
        assert.equal(true, await instance.isAdopted(0));

        await instance.adopt(1, { from: accounts[1] });
        assert.equal(accounts[1], await instance.adopterOf(1));
        assert.equal(true, await instance.isAdopted(1));

        const tx = await instance.assignName(1, "pet 1", { from: accounts[1] });
        truffleAssert.eventEmitted(tx, 'NameAssigned', (event) => {
            return (event.name === '0x7065742031000000000000000000000000000000000000000000000000000000');
        });

    });

    it("should allow transfer", async () => {

        await instance.createAdoptee(1, { from: accounts[0] });
        await instance.adopt(1, { from: accounts[1] });
        assert.equal(accounts[1], await instance.adopterOf(1));
        assert.equal(true, await instance.isAdopted(1));

        await instance.transfer(1, accounts[2], { from: accounts[1] });
        assert.equal(accounts[2], await instance.adopterOf(1));
        assert.equal(true, await instance.isAdopted(1));

        truffleAssert.fails(
            instance.transfer(1, accounts[1], { from: accounts[1] }),
            truffleAssert.ErrorType.REVERT
        );

        await instance.transfer(1, accounts[1], { from: accounts[2] });
        assert.equal(accounts[1], await instance.adopterOf(1));
        assert.equal(true, await instance.isAdopted(1));

    });

    it("should not allow creation of adoptee by non-contract owner", async () => {

        truffleAssert.fails(
            instance.createAdoptee(0, { from: accounts[1] }),
            truffleAssert.ErrorType.REVERT
        );
    });

    it("should not allow re-adoption", async () => {

        await instance.createAdoptee(1, { from: accounts[0] });
        await instance.adopt(1, { from: accounts[1] });
        assert.equal(accounts[1], await instance.adopterOf(1));
        assert.equal(true, await instance.isAdopted(1));

        truffleAssert.fails(
            instance.adopt(1, { from: accounts[0] }),
            truffleAssert.ErrorType.REVERT
        );

        truffleAssert.fails(
            instance.adopt(1, { from: accounts[2] }),
            truffleAssert.ErrorType.REVERT
        );

        instance.assignName(1, { from: accounts[1] });

        truffleAssert.fails(
            instance.assignName(1, "pet 1", { from: accounts[2] }),
            truffleAssert.ErrorType.REVERT
        );
    });

    it("should not allow operations on non-existent pet", async () => {

        truffleAssert.fails(
            instance.adopt(0, { from: accounts[0] }),
            truffleAssert.ErrorType.REVERT
        );
        truffleAssert.fails(
            instance.adopterOf(0),
            truffleAssert.ErrorType.REVERT
        );
        truffleAssert.fails(
            instance.isAdopted(0),
            truffleAssert.ErrorType.REVERT
        );
        truffleAssert.fails(
            instance.assignName(0, "pet 0"),
            truffleAssert.ErrorType.REVERT
        );
        truffleAssert.fails(
            instance.transfer(0, accounts[1]),
            truffleAssert.ErrorType.REVERT
        );

        truffleAssert.fails(
            instance.adopt(1, { from: accounts[0] }),
            truffleAssert.ErrorType.REVERT
        );
        truffleAssert.fails(
            instance.isAdopted(1),
            truffleAssert.ErrorType.REVERT
        );
        truffleAssert.fails(
            instance.adopterOf(1),
            truffleAssert.ErrorType.REVERT
        );
        truffleAssert.fails(
            instance.assignName(1, "pet 1"),
            truffleAssert.ErrorType.REVERT
        );
        truffleAssert.fails(
            instance.transfer(1, accounts[1]),
            truffleAssert.ErrorType.REVERT
        );

    });
});