// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/MockERC20.sol";
import "../src/MockYieldSource.sol";
import "../src/VaultV1.sol";

/// @notice Deployment script for the full vault stack.
///         Usage: forge script script/Deploy.s.sol --rpc-url $RPC --broadcast
contract DeployVault is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // 1. Deploy mock token (replace with real asset on mainnet)
        MockERC20 token = new MockERC20("USD Coin", "USDC", 6);

        // 2. Deploy yield source
        MockYieldSource yieldSource = new MockYieldSource(address(token));

        // 3. Deploy VaultV1 implementation
        VaultV1 vaultImpl = new VaultV1();

        // 4. Encode initializer call
        bytes memory initData = abi.encodeCall(
            VaultV1.initialize,
            (IERC20(address(token)), "Yield Vault USDC", "yvUSDC", address(yieldSource), deployer)
        );

        // 5. Deploy ERC-1967 proxy pointing to VaultV1
        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImpl), initData);

        vm.stopBroadcast();

        console.log("Token:        ", address(token));
        console.log("YieldSource:  ", address(yieldSource));
        console.log("VaultV1 Impl: ", address(vaultImpl));
        console.log("Proxy (Vault):", address(proxy));
    }
}
