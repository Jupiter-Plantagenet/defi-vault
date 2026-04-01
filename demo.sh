#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "  DeFi Vault — Demo Runner"
echo "========================================="
echo ""

# Check prerequisites
if ! command -v forge &> /dev/null; then
  echo "ERROR: 'forge' not found. Install Foundry: https://getfoundry.sh"
  exit 1
fi

echo "[1/4] Checking dependencies..."
if [ ! -d "lib/forge-std" ]; then
  echo "  Installing Foundry dependencies..."
  forge install
else
  echo "  Dependencies already installed."
fi

echo ""
echo "[2/4] Building contracts..."
forge build --sizes

echo ""
echo "[3/4] Running tests..."
forge test -vvv

echo ""
echo "[4/4] Gas report..."
forge test --gas-report

echo ""
echo "========================================="
echo "  All tests passed!"
echo "========================================="
echo ""
echo "To deploy locally:"
echo "  anvil &"
echo "  forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast"
