// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./VaultV1.sol";

/// @title VaultV2
/// @notice Upgraded vault with a configurable performance fee on harvested yield.
///         Demonstrates UUPS upgradeability — deployed via `upgradeTo(VaultV2)`.
contract VaultV2 is VaultV1 {
    uint256 public feeBps;
    address public feeRecipient;

    uint256 public constant MAX_FEE_BPS = 2000; // 20% cap

    event FeeConfigured(uint256 feeBps, address recipient);
    event FeesCollected(uint256 amount, address recipient);

    /// @notice Configure the performance fee (owner only).
    /// @param feeBps_       Fee in basis points (e.g., 500 = 5%).
    /// @param feeRecipient_ Address that receives collected fees.
    function configureFee(uint256 feeBps_, address feeRecipient_) external onlyOwner {
        require(feeBps_ <= MAX_FEE_BPS, "VaultV2: fee too high");
        require(feeRecipient_ != address(0), "VaultV2: zero address");
        feeBps = feeBps_;
        feeRecipient = feeRecipient_;
        emit FeeConfigured(feeBps_, feeRecipient_);
    }

    /// @notice Harvest yield and skim the performance fee to the fee recipient.
    function harvestWithFee() external onlyOwner {
        uint256 before = yieldSource.totalAssets();
        yieldSource.accrueYield();
        uint256 after_ = yieldSource.totalAssets();

        uint256 profit = after_ > before ? after_ - before : 0;
        if (profit > 0 && feeBps > 0 && feeRecipient != address(0)) {
            uint256 fee = (profit * feeBps) / 10_000;
            yieldSource.withdraw(fee, feeRecipient);
            emit FeesCollected(fee, feeRecipient);
        }

        emit YieldHarvested(yieldSource.totalAssets());
    }

    /// @notice Returns V2 identifier.
    function version() external pure override returns (string memory) {
        return "2.0.0";
    }
}
