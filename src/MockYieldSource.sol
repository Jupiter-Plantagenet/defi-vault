// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MockYieldSource
/// @notice Simulates a yield-generating protocol. Deposits earn a fixed APY
///         that is realized when `accrueYield()` is called by the vault or a keeper.
contract MockYieldSource {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    uint256 public constant YIELD_BPS = 500; // 5% yield per accrual (demo)
    uint256 public totalDeposited;

    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);
    event YieldAccrued(uint256 yieldAmount);

    constructor(address asset_) {
        asset = IERC20(asset_);
    }

    /// @notice Deposit assets into the yield source.
    function deposit(uint256 amount) external {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        totalDeposited += amount;
        emit Deposited(msg.sender, amount);
    }

    /// @notice Withdraw assets from the yield source.
    function withdraw(uint256 amount, address to) external {
        require(amount <= asset.balanceOf(address(this)), "Insufficient balance");
        totalDeposited = totalDeposited > amount ? totalDeposited - amount : 0;
        asset.safeTransfer(to, amount);
        emit Withdrawn(to, amount);
    }

    /// @notice Simulate yield accrual by minting new tokens to this contract.
    /// @dev In production this would come from lending interest, LP fees, etc.
    ///      For demo purposes we rely on the MockERC20 mint function.
    function accrueYield() external {
        uint256 yieldAmount = (totalDeposited * YIELD_BPS) / 10_000;
        if (yieldAmount > 0) {
            // Call mint on the mock token — only works with MockERC20
            (bool success,) = address(asset).call(
                abi.encodeWithSignature("mint(address,uint256)", address(this), yieldAmount)
            );
            require(success, "Yield accrual failed");
            emit YieldAccrued(yieldAmount);
        }
    }

    /// @notice Total assets held, including unrealized yield.
    function totalAssets() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
