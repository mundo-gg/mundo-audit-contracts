// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import "../src/Mundo.sol";

contract MundoTest is Test {
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant BURNER_ROLE = keccak256("BURNER_ROLE");

    Mundo token;

    function setUp() public {
        token = new Mundo();
    }

    function testMetadata() public {
        assertEq(token.name(), "Mundo");
        assertEq(token.symbol(), "MND");
        assertEq(token.totalSupply(), 200000000e18);
    }

    function testGrantMintRole() public {
        token.grantRole(MINTER_ROLE, address(0xBEEF));
        assert(token.hasRole(MINTER_ROLE, address(0xBEEF)));
    }

    function testGrantBurnerRole() public {
        token.grantRole(BURNER_ROLE, address(0xBEEF));
        assert(token.hasRole(BURNER_ROLE, address(0xBEEF)));
    }

    function testMint() public {
        uint256 previousTS = token.totalSupply();

        token.grantRole(MINTER_ROLE, address(this));
        token.mint(address(0xBEEF), 1e18);

        assertEq(token.totalSupply(), previousTS + 1e18);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testPaused() public {
        token.pause();
        assertTrue(token.paused());        
    }

    function testAllowTransferWhitelistAddressWhenPaused() public {
        uint256 previousTS = token.totalSupply();

        address allowTransferee = address(0x123);
        address[] memory allowList = new address[](1);
        allowList[0] = allowTransferee;
        token.addToAllowedList(allowList);

        token.grantRole(MINTER_ROLE, address(this));
        token.mint(allowTransferee, 1e18);
        token.pause();

        vm.prank(allowTransferee);
        token.transfer(address(0xBEEF), 1e18);

        assertTrue(token.paused());
        assertEq(token.balanceOf(allowTransferee), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
        assertEq(token.totalSupply(), previousTS + 1e18);
    }

    function testBurn() public {
        uint256 previousTS = token.totalSupply();
        // add mint and burner role
        token.grantRole(MINTER_ROLE, address(this));
        token.grantRole(BURNER_ROLE, address(this));

        token.mint(address(0xBEEF), 1e18);
        token.burn(address(0xBEEF), 0.9e18);

        assertEq(token.totalSupply(), previousTS + 1e18 - 0.9e18);
        assertEq(token.balanceOf(address(0xBEEF)), 0.1e18);
    }

    function testApprove() public {
        assertTrue(token.approve(address(0xBEEF), 1e18));
        assertEq(token.allowance(address(this), address(0xBEEF)), 1e18);
    }

    function testTransfer() public {
        assertTrue(token.transfer(address(0xBEEF), 1e18));
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testTransferFrom() public {
        uint256 previousTS = token.totalSupply();
        token.grantRole(MINTER_ROLE, address(this));
        address from = address(0xABCD);

        token.mint(from, 1e18);

        vm.prank(from);
        token.approve(address(this), 1e18);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), previousTS + 1e18);

        assertEq(token.allowance(from, address(this)), 0);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testInfiniteApproveTransferFrom() public {
        uint256 previousTS = token.totalSupply();
        token.grantRole(MINTER_ROLE, address(this));
        address from = address(0xABCD);

        token.mint(from, 1e18);

        vm.prank(from);
        token.approve(address(this), type(uint256).max);

        assertTrue(token.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(token.totalSupply(), previousTS + 1e18);

        assertEq(token.allowance(from, address(this)), type(uint256).max);

        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function testFailPauseWhenNotAdmin() public {
        address unAuthorizeAddress = address(0xBEEF);
        vm.prank(unAuthorizeAddress);
        token.pause();
    }

    function testFailTransferWhenPaused() public {
        token.grantRole(MINTER_ROLE, address(this));
        address from = address(0xABCD);

        token.mint(from, 1e18);
        token.pause();

        vm.prank(from);
        token.transfer(address(0xBEEF), 1e18);
    }

    function testFailNoMinterRole() public {
        address unAuthorizeAddress = address(0xBEEF);
        vm.prank(unAuthorizeAddress);
        token.mint(address(0xABCD), 1e18);
    }

    function testFailNoBurnerRole() public {
        address unAuthorizeAddress = address(0xBEEF);
        vm.prank(unAuthorizeAddress);
        token.burn(address(0xABCD), 1e18);
    }

    function testFailTransferInsufficientBalance() public {
        token.grantRole(MINTER_ROLE, address(this));
        address from = address(0xABCD);

        token.mint(from, 0.9e18);
        vm.prank(from);
        token.transfer(address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientAllowance() public {
        token.grantRole(MINTER_ROLE, address(this));
        address from = address(0xABCD);

        token.mint(from, 1e18);

        vm.prank(from);
        token.approve(address(this), 0.9e18);

        token.transferFrom(from, address(0xBEEF), 1e18);
    }

    function testFailTransferFromInsufficientBalance() public {
        token.grantRole(MINTER_ROLE, address(this));
        address from = address(0xABCD);

        token.mint(from, 0.9e18);

        vm.prank(from);
        token.approve(address(this), 1e18);

        token.transferFrom(from, address(0xBEEF), 1e18);
    }

    // Fuzz test

    function testMint(address from, uint256 amount) public {
        uint256 previousTS = token.totalSupply();

        vm.assume(from != address(0x0));
        vm.assume(amount < UINT256_MAX - previousTS);

        token.grantRole(MINTER_ROLE, address(this));
        token.mint(from, amount);

        assertEq(token.totalSupply(), previousTS + amount);
        assertEq(token.balanceOf(from), amount);
    }

    function testBurn(
        address from,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        uint256 previousTS = token.totalSupply();

        vm.assume(from != address(0x0));
        vm.assume(mintAmount > burnAmount);
        vm.assume(mintAmount < UINT256_MAX - previousTS);
        vm.assume(burnAmount < mintAmount + previousTS && burnAmount < UINT256_MAX);

        token.grantRole(MINTER_ROLE, address(this));
        token.grantRole(BURNER_ROLE, address(this));

        burnAmount = bound(burnAmount, 0, mintAmount);

        token.mint(from, mintAmount);
        token.burn(from, burnAmount);

        assertEq(token.totalSupply(), previousTS + mintAmount - burnAmount);
        assertEq(token.balanceOf(from), mintAmount - burnAmount);
    }

    function testApprove(address to, uint256 amount) public {
        vm.assume(to != address(0x0));
        assertTrue(token.approve(to, amount));

        assertEq(token.allowance(address(this), to), amount);
    }

    function testTransfer(address from, uint256 amount) public {
        uint256 previousBalance = token.balanceOf(address(this));

        vm.assume(from != address(0x0));
        vm.assume(from != address(this));
        vm.assume(amount < previousBalance);

        assertTrue(token.transfer(from, amount));
        assertEq(token.balanceOf(address(this)), previousBalance - amount);
        assertEq(token.balanceOf(from), amount);
    }

}