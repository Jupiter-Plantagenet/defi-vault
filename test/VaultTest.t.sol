// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/MockERC20.sol";
import "../src/MockYieldSource.sol";
import "../src/VaultV1.sol";
import "../src/VaultV2.sol";

contract VaultTest is Test {
    MockERC20 token;
    MockYieldSource yieldSource;
    VaultV1 vault;
    ERC1967Proxy proxy;

    address owner = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant INITIAL_BALANCE = 100_000e6; // 100k USDC

    function setUp() public {
        // Deploy stack
        token = new MockERC20("USD Coin", "USDC", 6);
        yieldSource = new MockYieldSource(address(token));

        VaultV1 impl = new VaultV1();
        bytes memory initData = abi.encodeCall(
            VaultV1.initialize,
            (IERC20(address(token)), "Yield Vault USDC", "yvUSDC", address(yieldSource), owner)
        );
        proxy = new ERC1967Proxy(address(impl), initData);
        vault = VaultV1(address(proxy));

        // Fund users
        token.mint(alice, INITIAL_BALANCE);
        token.mint(bob, INITIAL_BALANCE);
    }

    // ───────── Deposit / Withdraw ─────────

    function test_deposit() public {
        uint256 amount = 10_000e6;
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, alice);
        vm.stopPrank();

        assertGt(shares, 0, "Should receive shares");
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), amount);
    }

    function test_withdraw() public {
        uint256 amount = 10_000e6;
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.deposit(amount, alice);

        uint256 sharesBurned = vault.withdraw(amount, alice, alice);
        vm.stopPrank();

        assertGt(sharesBurned, 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(token.balanceOf(alice), INITIAL_BALANCE);
    }

    function test_multipleDepositors() public {
        uint256 amount = 5_000e6;

        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.deposit(amount, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(vault), amount);
        vault.deposit(amount, bob);
        vm.stopPrank();

        assertEq(vault.totalAssets(), amount * 2);
        assertEq(vault.balanceOf(alice), vault.balanceOf(bob));
    }

    // ───────── Yield ─────────

    function test_harvest_increases_totalAssets() public {
        uint256 amount = 10_000e6;
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.deposit(amount, alice);
        vm.stopPrank();

        uint256 assetsBefore = vault.totalAssets();
        vault.harvest();
        uint256 assetsAfter = vault.totalAssets();

        assertGt(assetsAfter, assetsBefore, "Yield should increase totalAssets");
    }

    function test_yield_distributed_proportionally() public {
        vm.startPrank(alice);
        token.approve(address(vault), 10_000e6);
        vault.deposit(10_000e6, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(vault), 10_000e6);
        vault.deposit(10_000e6, bob);
        vm.stopPrank();

        vault.harvest(); // 5% yield

        // Both should be able to withdraw more than deposited
        uint256 aliceMax = vault.maxWithdraw(alice);
        uint256 bobMax = vault.maxWithdraw(bob);
        assertGt(aliceMax, 10_000e6);
        assertEq(aliceMax, bobMax, "Equal depositors get equal yield");
    }

    // ───────── Upgrade ─────────

    function test_upgrade_to_v2() public {
        VaultV2 v2Impl = new VaultV2();
        vault.upgradeToAndCall(address(v2Impl), "");

        VaultV2 vaultV2 = VaultV2(address(proxy));
        assertEq(keccak256(bytes(vaultV2.version())), keccak256(bytes("2.0.0")));
    }

    function test_upgrade_preserves_state() public {
        // Deposit first
        vm.startPrank(alice);
        token.approve(address(vault), 10_000e6);
        vault.deposit(10_000e6, alice);
        vm.stopPrank();

        uint256 sharesBefore = vault.balanceOf(alice);
        uint256 totalBefore = vault.totalAssets();

        // Upgrade
        VaultV2 v2Impl = new VaultV2();
        vault.upgradeToAndCall(address(v2Impl), "");

        VaultV2 vaultV2 = VaultV2(address(proxy));
        assertEq(vaultV2.balanceOf(alice), sharesBefore, "Shares preserved after upgrade");
        assertEq(vaultV2.totalAssets(), totalBefore, "Total assets preserved after upgrade");
    }

    function test_v2_fee_collection() public {
        // Deposit
        vm.startPrank(alice);
        token.approve(address(vault), 10_000e6);
        vault.deposit(10_000e6, alice);
        vm.stopPrank();

        // Upgrade to V2
        VaultV2 v2Impl = new VaultV2();
        vault.upgradeToAndCall(address(v2Impl), "");
        VaultV2 vaultV2 = VaultV2(address(proxy));

        // Configure 10% fee
        address feeRecipient = makeAddr("treasury");
        vaultV2.configureFee(1000, feeRecipient);

        // Harvest with fee
        vaultV2.harvestWithFee();

        assertGt(token.balanceOf(feeRecipient), 0, "Fee recipient should receive tokens");
    }

    // ───────── Access Control ─────────

    function test_onlyOwner_harvest() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.harvest();
    }

    function test_onlyOwner_upgrade() public {
        VaultV2 v2Impl = new VaultV2();
        vm.prank(alice);
        vm.expectRevert();
        vault.upgradeToAndCall(address(v2Impl), "");
    }

    // ───────── ERC-4626 Compliance ─────────

    function test_previewDeposit_matches_actual() public {
        uint256 amount = 5_000e6;
        uint256 preview = vault.previewDeposit(amount);

        vm.startPrank(alice);
        token.approve(address(vault), amount);
        uint256 actual = vault.deposit(amount, alice);
        vm.stopPrank();

        assertEq(preview, actual, "Preview should match actual shares");
    }

    function test_maxDeposit_returns_max() public {
        uint256 max = vault.maxDeposit(alice);
        assertEq(max, type(uint256).max);
    }
}
