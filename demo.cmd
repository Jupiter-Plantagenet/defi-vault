@echo off
echo =========================================
echo   DeFi Vault — Demo Runner
echo =========================================
echo.

where forge >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: 'forge' not found. Install Foundry: https://getfoundry.sh
    exit /b 1
)

echo [1/4] Checking dependencies...
if not exist "lib\forge-std" (
    echo   Installing Foundry dependencies...
    forge install
) else (
    echo   Dependencies already installed.
)

echo.
echo [2/4] Building contracts...
forge build --sizes

echo.
echo [3/4] Running tests...
forge test -vvv

echo.
echo [4/4] Gas report...
forge test --gas-report

echo.
echo =========================================
echo   All tests passed!
echo =========================================
echo.
echo To deploy locally:
echo   anvil
echo   forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
