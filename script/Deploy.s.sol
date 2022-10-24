// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Script.sol";
import { SharedGrants } from 'src/SharedGrants.sol';

contract Deploy is Script {
    function setUp() public {}

    function run() public returns (address contractAddress) {
        vm.broadcast();
        contractAddress = address(new SharedGrants());
    }
}