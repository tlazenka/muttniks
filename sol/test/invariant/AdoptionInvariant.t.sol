// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Adoption} from "../../src/Adoption.sol";
import {AdoptionHandler} from "./AdoptionHandler.sol";

contract AdoptionInvariantTest is Test {
    Adoption internal adoption;
    AdoptionHandler internal handler;

    function setUp() public {
        handler = new AdoptionHandlerWithDeployment();
        adoption = handler.adoption();
        targetContract(address(handler));
    }

    function invariant_ModelMatchesEveryCreatedPet() public view {
        uint256 count = handler.createdPetCount();
        for (uint256 i; i < count; ++i) {
            uint256 petId = handler.createdPetIdAt(i);
            assertTrue(handler.modelExists(petId));
            assertEq(adoption.adopterOf(petId), handler.modelAdopter(petId));
            assertEq(adoption.isAdopted(petId), handler.modelAdopter(petId) != address(0));
        }
    }

    function invariant_AdoptedPetsNeverHaveZeroAdopter() public view {
        uint256 count = handler.createdPetCount();
        for (uint256 i; i < count; ++i) {
            uint256 petId = handler.createdPetIdAt(i);
            if (adoption.isAdopted(petId)) {
                assertTrue(adoption.adopterOf(petId) != address(0));
            }
        }
    }
}

contract AdoptionHandlerWithDeployment is AdoptionHandler {
    constructor() AdoptionHandler(new Adoption()) {}
}
