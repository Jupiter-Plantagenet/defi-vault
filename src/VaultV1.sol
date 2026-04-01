// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IYieldSource {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount, address to) external;
    function accrueYield() external;
    function totalAssets() external view returns (uint256);
}

/// @title VaultV1
/// @notice ERC-4626 compliant yield vault with UUPS upgradeability.
///         Deposits user funds into a yield source and distributes returns proportionally.
/// @dev    Uses OpenZeppelin v5 upgradeable contracts.
contract VaultV1 is ERC4626Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    IYieldSource public yieldSource;

    event YieldSourceUpdated(address indexed newSource);
    event YieldHarvested(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the vault (called once via proxy).
    /// @param asset_       The underlying ERC-20 token.
    /// @param name_        Vault share token name.
    /// @param symbol_      Vault share token symbol.
    /// @param yieldSource_ Address of the yield-generating protocol.
    /// @param owner_       Admin address that can upgrade and configure.
    function initialize(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address yieldSource_,
        address owner_
    ) external initializer {
        __ERC4626_init(asset_);
        __ERC20_init(name_, symbol_);
        __Ownable_init(owner_);

        yieldSource = IYieldSource(yieldSource_);
    }

    // ──────────────────────────── ERC-4626 Overrides ────────────────────────────

    /// @notice Total assets managed by this vault = idle balance + assets in yield source.
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + yieldSource.totalAssets();
    }

    /// @dev After a deposit, forward idle funds into the yield source.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares);
        _deployToYield(assets);
    }

    /// @dev Before a withdrawal, pull funds back from the yield source if needed.
    function _withdraw(
        address caller,
        address receiver,
        address _owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        if (idle < assets) {
            yieldSource.withdraw(assets - idle, address(this));
        }
        super._withdraw(caller, receiver, _owner, assets, shares);
    }

    // ──────────────────────────── Yield Management ──────────────────────────────

    /// @notice Deploy idle vault assets into the yield source.
    function _deployToYield(uint256 amount) internal {
        IERC20(asset()).approve(address(yieldSource), amount);
        yieldSource.deposit(amount);
    }

    /// @notice Trigger yield accrual on the underlying source (keeper/owner call).
    function harvest() external onlyOwner {
        yieldSource.accrueYield();
        emit YieldHarvested(yieldSource.totalAssets());
    }

    /// @notice Update the yield source address (owner only).
    function setYieldSource(address newSource) external onlyOwner {
        require(newSource != address(0), "VaultV1: zero address");
        yieldSource = IYieldSource(newSource);
        emit YieldSourceUpdated(newSource);
    }

    // ──────────────────────────── UUPS ──────────────────────────────────────────

    /// @dev Only the owner can authorize upgrades.
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @notice Returns the vault version for identification.
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
