// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Adoption} from "../src/Adoption.sol";

contract DeployAdoption is Script {
    function run() external returns (Adoption adoption) {
        vm.startBroadcast();
        adoption = new Adoption();
        adoption.createAdoptee(32);
        vm.stopBroadcast();
    }
}
