// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../src/FoodFightNFT.sol";
import "forge-std/Test.sol";

contract FoodFightNFTTest is Test {
    FoodFightNFT nft;
    address alice;
    address bob;
    address dev;
    address manager;
    address curator;
    uint256 mintPrice;
    uint256 initialSupply;
    uint256 curatorAmount;
    uint256 managerAmount;
    uint256 devAmount;

    function setUp() public {
        alice = address(1);
        bob = address(2);

        vm.label(alice, "alice");
        vm.label(bob, "alice");
        vm.label(address(this), "deployer");

        nft = new FoodFightNFT();
        dev = nft.DEV();
        manager = nft.MANAGER();
        curator = nft.CURATOR();
        vm.label(dev, "dev");
        vm.label(manager, "manager");
        vm.label(curator, "curator");

        mintPrice = nft.mintPrice();
        initialSupply = nft.totalSupply();
        assertEq(initialSupply, 2);
        assertEq(nft.ownerOf(1), manager);
        assertEq(nft.ownerOf(2), dev);

        curatorAmount = (mintPrice * nft.CURATOR_CUT()) / nft.TOTAL_CUT();
        managerAmount = (mintPrice * nft.MANAGER_CUT()) / nft.TOTAL_CUT();
        devAmount = mintPrice - curatorAmount - managerAmount;

        nft.setMintStartTimestamp(block.timestamp);
        vm.warp(block.timestamp + nft.WL_MINT_DURATION());
    }

    function testPublicMint() public {
        vm.deal(alice, mintPrice);
        vm.startPrank(alice);
        nft.mint{value: mintPrice}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.ownerOf(3), alice);
        assertEq(nft.totalSupply(), 1 + initialSupply);
        assertEq(nft.CURATOR().balance, curatorAmount);
        assertEq(nft.MANAGER().balance, managerAmount);
        assertEq(nft.DEV().balance, devAmount);
    }

    function testPublicMintWithoutPayment() public {
        vm.expectRevert(FoodFightNFT.MintPriceNotPaid.selector);
        vm.startPrank(alice);
        nft.mint{value: 0}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), initialSupply);
        assertEq(nft.CURATOR().balance, 0);
        assertEq(nft.MANAGER().balance, 0);
        assertEq(nft.DEV().balance, 0);
    }

    function testPublicMintWithExcessPayment() public {
        vm.deal(alice, mintPrice + 1);
        vm.startPrank(alice);
        nft.mint{value: mintPrice + 1}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.ownerOf(3), alice);
        assertEq(nft.totalSupply(), 1 + initialSupply);
        assertEq(nft.CURATOR().balance, curatorAmount);
        assertEq(nft.MANAGER().balance, managerAmount);
        assertEq(nft.DEV().balance, devAmount);
        assertEq(alice.balance, 1);
    }

    function testPublicMintWithInsufficientPayment() public {
        vm.expectRevert(FoodFightNFT.MintPriceNotPaid.selector);
        vm.deal(alice, mintPrice - 1);
        vm.startPrank(alice);
        nft.mint{value: mintPrice - 1}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), initialSupply);
        assertEq(nft.CURATOR().balance, 0);
        assertEq(nft.MANAGER().balance, 0);
        assertEq(nft.DEV().balance, 0);
        assertEq(alice.balance, mintPrice - 1);
    }

    function testPublicMintWithZeroAmount() public {
        vm.expectRevert(FoodFightNFT.InvalidAmount.selector);
        vm.deal(alice, mintPrice);
        vm.startPrank(alice);
        nft.mint{value: mintPrice}(0);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), initialSupply);
        assertEq(nft.CURATOR().balance, 0);
        assertEq(nft.MANAGER().balance, 0);
        assertEq(nft.DEV().balance, 0);
        assertEq(alice.balance, mintPrice);
    }

    function testPublicMintNonOneAmount() public {
        vm.expectRevert(FoodFightNFT.InvalidAmount.selector);
        vm.deal(alice, mintPrice);
        vm.startPrank(alice);
        nft.mint{value: mintPrice}(2);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), initialSupply);
        assertEq(nft.CURATOR().balance, 0);
        assertEq(nft.MANAGER().balance, 0);
        assertEq(nft.DEV().balance, 0);
        assertEq(alice.balance, mintPrice);
    }

    function testPublicMintingNotStarted() public {
        nft.setMintStartTimestamp(block.timestamp);
        vm.deal(alice, mintPrice);

        vm.expectRevert(Whitelistable.NotEnoughWhitelistSpots.selector);
        vm.startPrank(alice);
        nft.mint{value: mintPrice}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), initialSupply);
        assertEq(nft.CURATOR().balance, 0);
        assertEq(nft.MANAGER().balance, 0);
        assertEq(nft.DEV().balance, 0);
        assertEq(alice.balance, mintPrice);
    }

    function testWhitelistMint() public {
        vm.warp(nft.mintStartTimestamp());

        nft.addWhitelistSpots(alice, 1);
        vm.deal(alice, mintPrice);
        vm.startPrank(alice);
        nft.mint{value: mintPrice}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.ownerOf(3), alice);
        assertEq(nft.totalSupply(), 1 + initialSupply);
        assertEq(nft.CURATOR().balance, curatorAmount);
        assertEq(nft.MANAGER().balance, managerAmount);
        assertEq(nft.DEV().balance, devAmount);
    }

    function testWhitelistMintWithoutPayment() public {
        vm.warp(nft.mintStartTimestamp());

        nft.addWhitelistSpots(alice, 1);
        vm.expectRevert(FoodFightNFT.MintPriceNotPaid.selector);
        vm.startPrank(alice);
        nft.mint{value: 0}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), initialSupply);
        assertEq(nft.CURATOR().balance, 0);
        assertEq(nft.MANAGER().balance, 0);
        assertEq(nft.DEV().balance, 0);
    }

    function testWhitelistMintWithExcessPayment() public {
        vm.warp(nft.mintStartTimestamp());

        nft.addWhitelistSpots(alice, 1);
        vm.deal(alice, mintPrice + 1);
        vm.startPrank(alice);
        nft.mint{value: mintPrice + 1}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.ownerOf(3), alice);
        assertEq(nft.totalSupply(), 1 + initialSupply);
        assertEq(nft.CURATOR().balance, curatorAmount);
        assertEq(nft.MANAGER().balance, managerAmount);
        assertEq(nft.DEV().balance, devAmount);
        assertEq(alice.balance, 1);
    }

    function testWhitelistMintWithInsufficientPayment() public {
        vm.warp(nft.mintStartTimestamp());

        nft.addWhitelistSpots(alice, 1);
        vm.expectRevert(FoodFightNFT.MintPriceNotPaid.selector);
        vm.deal(alice, mintPrice - 1);
        vm.startPrank(alice);
        nft.mint{value: mintPrice - 1}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), initialSupply);
        assertEq(nft.CURATOR().balance, 0);
        assertEq(nft.MANAGER().balance, 0);
        assertEq(nft.DEV().balance, 0);
        assertEq(alice.balance, mintPrice - 1);
    }

    function testWhitelistMintWithZeroAmount() public {
        vm.expectRevert(FoodFightNFT.InvalidAmount.selector);
        vm.deal(alice, mintPrice);
        vm.startPrank(alice);
        nft.mint{value: mintPrice}(0);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), initialSupply);
        assertEq(nft.CURATOR().balance, 0);
        assertEq(nft.MANAGER().balance, 0);
        assertEq(nft.DEV().balance, 0);
        assertEq(alice.balance, mintPrice);
    }

    function testWhitelistMintNonOneAmount() public {
        vm.expectRevert(FoodFightNFT.InvalidAmount.selector);
        vm.deal(alice, mintPrice);
        vm.startPrank(alice);
        nft.mint{value: mintPrice}(2);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), initialSupply);
        assertEq(nft.CURATOR().balance, 0);
        assertEq(nft.MANAGER().balance, 0);
        assertEq(nft.DEV().balance, 0);
        assertEq(alice.balance, mintPrice);
    }

    function testWhitelistMintingNotStarted() public {
        nft.setMintStartTimestamp(block.timestamp + 1);
        nft.addWhitelistSpots(alice, 1);
        vm.deal(alice, mintPrice);

        vm.expectRevert(FoodFightNFT.MintingNotStarted.selector);
        vm.startPrank(alice);
        nft.mint{value: mintPrice}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.totalSupply(), initialSupply);
        assertEq(nft.CURATOR().balance, 0);
        assertEq(nft.MANAGER().balance, 0);
        assertEq(nft.DEV().balance, 0);
        assertEq(alice.balance, mintPrice);
    }

    function testTokensOfOwner() public {
        assertEq(nft.tokensOfOwner(manager).length, 1);
        assertEq(nft.tokensOfOwner(manager)[0], 1);

        vm.deal(alice, mintPrice);
        vm.startPrank(alice);
        nft.mint{value: mintPrice}(1);
        vm.stopPrank();
        assertEq(nft.tokensOfOwner(alice).length, 1);
        assertEq(nft.tokensOfOwner(alice)[0], 3);

        vm.deal(alice, mintPrice);
        vm.startPrank(alice);
        nft.mint{value: mintPrice}(1);
        vm.stopPrank();
        assertEq(nft.tokensOfOwner(alice).length, 2);
        assertEq(nft.tokensOfOwner(alice)[0], 3);
        assertEq(nft.tokensOfOwner(alice)[1], 4);

        vm.prank(alice);
        nft.transferFrom(alice, bob, 3);
        assertEq(nft.tokensOfOwner(alice).length, 1);
        assertEq(nft.tokensOfOwner(alice)[0], 4);
        assertEq(nft.tokensOfOwner(bob).length, 1);
        assertEq(nft.tokensOfOwner(bob)[0], 3);
    }

    function testRoyaltyInfo() public {
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 100);
        assertEq(receiver, address(nft.ROYALTY_PAYMENT_SPLITTER()));
        assertEq(royaltyAmount, 6);
    }

    function testSetMintPrice() public {
        assertEq(nft.mintPrice(), mintPrice);
        nft.setMintPrice(100);
        assertEq(nft.mintPrice(), 100);
    }

    function testSetMintStartTimestamp() public {
        nft.setMintStartTimestamp(block.timestamp + 1);
        assertEq(nft.mintStartTimestamp(), block.timestamp + 1);
    }

    function testSetMintStartTimestampUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.setMintStartTimestamp(block.timestamp + 1);
    }

    function testSetDefaultRoyalty() public {
        nft.setDefaultRoyalty(address(this), 1000);
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 100);
        assertEq(receiver, address(this));
        assertEq(royaltyAmount, 10);
    }

    function testSetDefaultRoyaltyUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.setDefaultRoyalty(address(this), 1000);
    }

    function testSetBaseURI() public {
        nft.setBaseURI("https://example.com/");
        assertEq(nft.baseURI(), "https://example.com/");
        assertEq(nft.tokenURI(1), "https://example.com/1");
    }

    function testSetBaseURIUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.setBaseURI("https://example.com/");
    }

    function testAddWhitelistSpots() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.addWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 0);

        nft.addWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 1);
    }

    function testRemoveWhitelistSpots() public {
        nft.addWhitelistSpots(alice, 2);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.removeWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 2);

        vm.expectRevert(Whitelistable.NotEnoughWhitelistSpots.selector);
        nft.removeWhitelistSpots(alice, 3);
        assertEq(nft.whitelistSpots(alice), 2);

        nft.removeWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 1);
    }

    function testClearWhitelistSpots() public {
        nft.addWhitelistSpots(alice, 2);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.clearWhitelistSpots(alice);
        assertEq(nft.whitelistSpots(alice), 2);

        nft.clearWhitelistSpots(alice);
        assertEq(nft.whitelistSpots(alice), 0);
    }

    function testMultipleAddWhitelistSpots() public {
        address[] memory addresses = new address[](3);
        uint256[] memory amounts = new uint256[](2);

        vm.expectRevert(FoodFightNFT.ArrayLengthMismatch.selector);
        nft.addWhitelistSpots(addresses, amounts);

        amounts = new uint256[](3);

        addresses[0] = alice;
        addresses[1] = alice;
        addresses[2] = address(1337);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 2;
        nft.addWhitelistSpots(addresses, amounts);
        assertEq(nft.whitelistSpots(alice), 2);
        assertEq(nft.whitelistSpots(address(1337)), 2);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
