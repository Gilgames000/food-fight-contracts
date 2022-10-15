// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.14;

import "../src/FoodFightNFT.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Whitelist is Test {
    using Strings for uint256;
    using stdJson for string;

    mapping(uint256 => address) public chainIDToFoodFightNFT;
    FoodFightNFT public foodFightNFT;

    function setUp() public {
        console.log(
            "Running script on chain with ID:",
            block.chainid.toString()
        );

        chainIDToFoodFightNFT[
            43114
        ] = 0x807d68c02172EFc7022F4AB450e03bb7900969E8;

        foodFightNFT = FoodFightNFT(chainIDToFoodFightNFT[block.chainid]);
        require(address(foodFightNFT) != address(0), "chainID not supported");
    }

    function addWhitelistSpots(string memory filename) external {
        console.log(foodFightNFT.whitelistSpots(msg.sender));
        console.log(msg.sender);
        require(
            foodFightNFT.mintStartTimestamp() > block.timestamp,
            "minting already started"
        );
        console.log(block.timestamp.toString());
        console.log(foodFightNFT.mintStartTimestamp().toString());

        string memory root = string.concat(vm.projectRoot(), "/");
        string memory path = string.concat(root, filename);
        bytes memory json = vm.parseJson(vm.readFile(path));
        address[] memory addresses = abi.decode(json, (address[]));
        uint256[] memory amounts = new uint256[](addresses.length);

        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = 1;
        }

        vm.broadcast(msg.sender);
        foodFightNFT.addWhitelistSpots(addresses, amounts);
    }
}
