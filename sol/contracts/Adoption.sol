pragma solidity 0.4.23;

contract Adoption {
    event NameAssigned(uint256 indexed petId, bytes32 name);
    event Adopted(uint256 indexed petId, address indexed adopter);

    struct Pet {
        address adopter;
        bool exists;
    }

    mapping (uint256 => Pet) private pets;

    address public contractOwnerAddress = msg.sender;

    modifier messageSenderIsContractOwner() {
        require(msg.sender == contractOwnerAddress);
        _;
    }

    modifier messageSenderIsAdopter(uint256 petId) {
        require(pets[petId].exists);
        require(pets[petId].adopter == msg.sender);
        _;
    }

    modifier petExists(uint256 petId) {
        require(pets[petId].exists);
        _;
    }

    modifier petDoesNotExist(uint256 petId) {
        require(!(pets[petId].exists));
        _;
    }

    modifier petIsNotAdopted(uint256 petId) {
        require(pets[petId].exists);
        require(pets[petId].adopter == address(0));
        _;
    }

    modifier addressIsAdopter(address claimant, uint256 petId) {
        require(pets[petId].exists);
        require(pets[petId].adopter == claimant);
        _;
    }

    function transfer(uint256 petId, address to) public messageSenderIsAdopter(petId) petExists(petId) {
        pets[petId].adopter = to;
    }

    function createAdoptee(uint256 petId) public messageSenderIsContractOwner {
        Pet memory pet = Pet({
            adopter: address(0),
            exists: true
            });
        pets[petId] = pet;
    }

    function adopterOf(uint256 petId) public view petExists(petId) returns (address adopter) {
        adopter = pets[petId].adopter;
    }

    function adopt(uint256 petId) public petIsNotAdopted(petId) petExists(petId) {
        pets[petId].adopter = msg.sender;
        emit Adopted(petId, msg.sender);
    }

    function isAdopted(uint256 petId) public view petExists(petId) returns (bool adopted) {
        adopted = pets[petId].adopter != address(0);
    }

    function assignName(uint256 petId, bytes32 name) external messageSenderIsAdopter(petId) petExists(petId) {
        emit NameAssigned(petId, name);
    }
}
