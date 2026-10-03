// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Adoption} from "../../src/Adoption.sol";

contract AdoptionHandler is Test {
    Adoption public immutable adoption;
    address public immutable owner;

    uint256[] private _createdPetIds;
    mapping(uint256 => bool) public modelExists;
    mapping(uint256 => address) public modelAdopter;

    constructor(Adoption adoption_) {
        adoption = adoption_;
        owner = address(this);
    }

    function create(uint256 petId) external {
        if (modelExists[petId]) return;

        adoption.createAdoptee(petId);
        modelExists[petId] = true;
        _createdPetIds.push(petId);
    }

    function adopt(uint256 petSeed, address adopter) external {
        if (_createdPetIds.length == 0 || adopter == address(0)) return;

        uint256 petId = _createdPetIds[petSeed % _createdPetIds.length];
        if (modelAdopter[petId] != address(0)) return;

        vm.prank(adopter);
        adoption.adopt(petId);
        modelAdopter[petId] = adopter;
    }

    function transfer(uint256 petSeed, address to) external {
        if (_createdPetIds.length == 0 || to == address(0)) return;

        uint256 petId = _createdPetIds[petSeed % _createdPetIds.length];
        address from = modelAdopter[petId];
        if (from == address(0)) return;

        vm.prank(from);
        adoption.transfer(petId, to);
        modelAdopter[petId] = to;
    }

    function assignName(uint256 petSeed, bytes32 name) external {
        if (_createdPetIds.length == 0) return;

        uint256 petId = _createdPetIds[petSeed % _createdPetIds.length];
        address adopter = modelAdopter[petId];
        if (adopter == address(0)) return;

        vm.prank(adopter);
        adoption.assignName(petId, name);
    }

    function createdPetCount() external view returns (uint256) {
        return _createdPetIds.length;
    }

    function createdPetIdAt(uint256 index) external view returns (uint256) {
        return _createdPetIds[index];
    }
}
