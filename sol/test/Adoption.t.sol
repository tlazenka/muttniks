// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Adoption} from "../src/Adoption.sol";

contract AdoptionTest is Test {
    Adoption internal adoption;
    address internal owner;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    uint256 internal constant PET_ID = 32;

    function setUp() public {
        owner = address(this);
        adoption = new Adoption();
    }

    function testOwnerCanCreatePet() public {
        vm.expectEmit(true, false, false, true);
        emit Adoption.PetCreated(PET_ID);
        adoption.createAdoptee(PET_ID);
        assertFalse(adoption.isAdopted(PET_ID));
        assertEq(adoption.adopterOf(PET_ID), address(0));
    }

    function testNonOwnerCannotCreatePet() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Adoption.NotContractOwner.selector, alice));
        adoption.createAdoptee(PET_ID);
    }

    function testCannotRecreateExistingPet() public {
        adoption.createAdoptee(PET_ID);
        vm.expectRevert(abi.encodeWithSelector(Adoption.PetAlreadyExists.selector, PET_ID));
        adoption.createAdoptee(PET_ID);
    }

    function testAdopt() public {
        adoption.createAdoptee(PET_ID);
        vm.expectEmit(true, true, false, true);
        emit Adoption.Adopted(PET_ID, alice);
        vm.prank(alice);
        adoption.adopt(PET_ID);
        assertTrue(adoption.isAdopted(PET_ID));
        assertEq(adoption.adopterOf(PET_ID), alice);
    }

    function testCannotAdoptMissingPet() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Adoption.PetDoesNotExist.selector, PET_ID));
        adoption.adopt(PET_ID);
    }

    function testCannotAdoptTwice() public {
        adoption.createAdoptee(PET_ID);
        vm.prank(alice);
        adoption.adopt(PET_ID);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Adoption.PetAlreadyAdopted.selector, PET_ID));
        adoption.adopt(PET_ID);
    }

    function testAdopterCanTransfer() public {
        adoption.createAdoptee(PET_ID);
        vm.prank(alice);
        adoption.adopt(PET_ID);

        vm.expectEmit(true, true, true, true);
        emit Adoption.Transferred(PET_ID, alice, bob);
        vm.prank(alice);
        adoption.transfer(PET_ID, bob);
        assertEq(adoption.adopterOf(PET_ID), bob);
    }

    function testNonAdopterCannotTransfer() public {
        adoption.createAdoptee(PET_ID);
        vm.prank(alice);
        adoption.adopt(PET_ID);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Adoption.NotAdopter.selector, PET_ID, bob));
        adoption.transfer(PET_ID, bob);
    }

    function testCannotTransferToZeroAddress() public {
        adoption.createAdoptee(PET_ID);
        vm.prank(alice);
        adoption.adopt(PET_ID);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Adoption.InvalidAdopter.selector, address(0)));
        adoption.transfer(PET_ID, address(0));
    }

    function testAdopterCanAssignName() public {
        bytes32 name = bytes32("Laika");
        adoption.createAdoptee(PET_ID);
        vm.prank(alice);
        adoption.adopt(PET_ID);
        vm.expectEmit(true, false, false, true);
        emit Adoption.NameAssigned(PET_ID, name);
        vm.prank(alice);
        adoption.assignName(PET_ID, name);
    }

    function testFuzz_NonOwnerCannotCreate(address caller, uint256 petId) public {
        vm.assume(caller != owner);
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Adoption.NotContractOwner.selector, caller));
        adoption.createAdoptee(petId);
    }

    function testFuzz_TransferChangesAdopter(uint256 petId, address from, address to) public {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        adoption.createAdoptee(petId);
        vm.prank(from);
        adoption.adopt(petId);
        vm.prank(from);
        adoption.transfer(petId, to);
        assertEq(adoption.adopterOf(petId), to);
    }
}
