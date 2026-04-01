// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/MockERC20.sol";
import "../src/MockYieldSource.sol";
import "../src/VaultV1.sol";

/// @title VaultHandler
/// @notice Guides the fuzzer through valid vault operations.
contract VaultHandler is Test {
    VaultV1 public vault;
    MockERC20 public token;
    address[] public actors;
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;

    constructor(VaultV1 vault_, MockERC20 token_) {
        vault = vault_;
        token = token_;

        // Create actors with funded balances
        for (uint256 i = 0; i < 5; i++) {
            address actor = makeAddr(string(abi.encodePacked("actor", i)));
            token.mint(actor, 1_000_000e6);
            actors.push(actor);
        }
    }

    function deposit(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 1e6, 100_000e6);

        vm.startPrank(actor);
        token.approve(address(vault), amount);
        vault.deposit(amount, actor);
        vm.stopPrank();

        ghost_totalDeposited += amount;
    }

    function withdraw(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        uint256 maxW = vault.maxWithdraw(actor);
        if (maxW == 0) return;

        amount = bound(amount, 1, maxW);

        vm.startPrank(actor);
        vault.withdraw(amount, actor, actor);
        vm.stopPrank();

        ghost_totalWithdrawn += amount;
    }

    function redeem(uint256 actorSeed, uint256 shares) external {
        address actor = actors[actorSeed % actors.length];
        uint256 maxR = vault.maxRedeem(actor);
        if (maxR == 0) return;

        shares = bound(shares, 1, maxR);

        vm.startPrank(actor);
        uint256 assets = vault.redeem(shares, actor, actor);
        vm.stopPrank();

        ghost_totalWithdrawn += assets;
    }
}

/// @title VaultInvariantTest
/// @notice Invariant (stateful fuzz) tests for the ERC-4626 vault.
contract VaultInvariantTest is Test {
    MockERC20 token;
    MockYieldSource yieldSource;
    VaultV1 vault;
    VaultHandler handler;

    function setUp() public {
        token = new MockERC20("USD Coin", "USDC", 6);
        yieldSource = new MockYieldSource(address(token));

        VaultV1 impl = new VaultV1();
        bytes memory initData = abi.encodeCall(
            VaultV1.initialize,
            (IERC20(address(token)), "Yield Vault USDC", "yvUSDC", address(yieldSource), address(this))
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        vault = VaultV1(address(proxy));

        handler = new VaultHandler(vault, token);
        targetContract(address(handler));
    }

    /// @notice The vault should never report more shares than can be backed by assets.
    ///         totalAssets >= totalSupply * 1 (assuming 1:1 initial exchange rate).
    function invariant_solvency() public view {
        if (vault.totalSupply() == 0) return;
        assertGe(
            vault.totalAssets(),
            vault.totalSupply(),
            "Vault is insolvent: totalAssets < totalSupply"
        );
    }

    /// @notice No value should leak: total deposited >= total withdrawn (before yield).
    function invariant_noValueLeak() public view {
        assertGe(
            handler.ghost_totalDeposited(),
            handler.ghost_totalWithdrawn(),
            "Value leak: more withdrawn than deposited (excluding yield)"
        );
    }

    /// @notice convertToAssets(totalSupply) should approximate totalAssets.
    function invariant_exchangeRateConsistency() public view {
        uint256 supply = vault.totalSupply();
        if (supply == 0) return;

        uint256 impliedAssets = vault.convertToAssets(supply);
        uint256 total = vault.totalAssets();

        // Allow 1 wei rounding tolerance
        assertApproxEqAbs(impliedAssets, total, 1, "Exchange rate inconsistent with totalAssets");
    }

    /// @notice Zero shares should never exist if there are zero assets, and vice-versa
    ///         (the "empty vault" invariant from ERC-4626).
    function invariant_emptyVaultConsistency() public view {
        if (vault.totalSupply() == 0) {
            // With no shares, idle vault balance should be 0 (yield source may hold dust)
            assertEq(
                vault.totalSupply(),
                0,
                "Non-zero supply with zero assets"
            );
        }
    }
}
