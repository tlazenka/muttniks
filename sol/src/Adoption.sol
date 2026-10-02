// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract Adoption {
    struct Pet {
        address adopter;
        bool exists;
    }

    error NotContractOwner(address caller);
    error PetAlreadyExists(uint256 petId);
    error PetDoesNotExist(uint256 petId);
    error PetAlreadyAdopted(uint256 petId);
    error NotAdopter(uint256 petId, address caller);
    error InvalidAdopter(address adopter);

    event PetCreated(uint256 indexed petId);
    event NameAssigned(uint256 indexed petId, bytes32 name);
    event Adopted(uint256 indexed petId, address indexed adopter);
    event Transferred(uint256 indexed petId, address indexed from, address indexed to);

    mapping(uint256 => Pet) private pets;
    address public immutable contractOwnerAddress;

    constructor() {
        contractOwnerAddress = msg.sender;
    }

    modifier onlyContractOwner() {
        if (msg.sender != contractOwnerAddress) revert NotContractOwner(msg.sender);
        _;
    }

    modifier petExists(uint256 petId) {
        if (!pets[petId].exists) revert PetDoesNotExist(petId);
        _;
    }

    modifier onlyAdopter(uint256 petId) {
        if (!pets[petId].exists) revert PetDoesNotExist(petId);
        if (pets[petId].adopter != msg.sender) revert NotAdopter(petId, msg.sender);
        _;
    }

    function createAdoptee(uint256 petId) external onlyContractOwner {
        if (pets[petId].exists) revert PetAlreadyExists(petId);
        pets[petId] = Pet({adopter: address(0), exists: true});
        emit PetCreated(petId);
    }

    function adopt(uint256 petId) external petExists(petId) {
        if (pets[petId].adopter != address(0)) revert PetAlreadyAdopted(petId);
        pets[petId].adopter = msg.sender;
        emit Adopted(petId, msg.sender);
    }

    function transfer(uint256 petId, address to) external onlyAdopter(petId) {
        if (to == address(0)) revert InvalidAdopter(to);
        address from = msg.sender;
        pets[petId].adopter = to;
        emit Transferred(petId, from, to);
    }

    function assignName(uint256 petId, bytes32 name) external onlyAdopter(petId) {
        emit NameAssigned(petId, name);
    }

    function adopterOf(uint256 petId) external view petExists(petId) returns (address) {
        return pets[petId].adopter;
    }

    function isAdopted(uint256 petId) external view petExists(petId) returns (bool) {
        return pets[petId].adopter != address(0);
    }
}
