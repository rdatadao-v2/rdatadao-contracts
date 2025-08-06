#!/bin/bash

# Fix RDAT initialization in security test files
echo "Fixing RDAT initialization in security tests..."

# Files that need the 3-parameter update
security_files=(
    "test/security/GriefingAttacks.t.sol"
    "test/security/MinStakeTest.t.sol"
    "test/security/PositionLimitDoS.t.sol"
    "test/security/PrecisionExploits.t.sol"
    "test/security/UpgradeSafety.t.sol"
)

for file in "${security_files[@]}"; do
    echo "Updating $file..."
    # Replace 2-parameter initialization with 3-parameter
    sed -i '' 's/(treasury, admin)/(treasury, admin, address(0x100)) \/\/ migration contract address/g' "$file"
done

# Also need to fix PositionLimitCore.t.sol
echo "Updating test/security/PositionLimitCore.t.sol..."
sed -i '' 's/(treasury, admin)/(treasury, admin, address(0x100)) \/\/ migration contract address/g' "test/security/PositionLimitCore.t.sol"

# Fix StakingPositionsUpgrade.t.sol
echo "Updating test/StakingPositionsUpgrade.t.sol..."
sed -i '' 's/(treasury, admin)/(treasury, admin, address(0x100)) \/\/ migration contract address/g' "test/StakingPositionsUpgrade.t.sol"

echo "Done!"