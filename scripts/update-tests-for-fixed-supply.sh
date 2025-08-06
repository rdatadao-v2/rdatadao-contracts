#!/bin/bash

# Script to update all test files for RDAT fixed supply changes

echo "Updating test files for RDAT fixed supply..."

# 1. Update initialize calls to include migration contract
echo "Updating initialize calls..."
find test -name "*.sol" -type f | while read -r file; do
    # Update 2-parameter initialize to 3-parameter
    sed -i '' 's/initialize,$/initialize,/g' "$file"
    sed -i '' 's/(treasury, admin)/(treasury, admin, address(0x100)) \/\/ migration contract address/g' "$file"
done

# 2. Remove MINTER_ROLE references
echo "Removing MINTER_ROLE references..."
find test -name "*.sol" -type f | while read -r file; do
    # Comment out MINTER_ROLE grants
    sed -i '' 's/rdat\.grantRole(rdat\.MINTER_ROLE(), /\/\/ RDAT no longer has MINTER_ROLE - /g' "$file"
done

# 3. Replace rdat.mint calls with treasury transfers
echo "Replacing rdat.mint calls..."
find test -name "*.sol" -type f | while read -r file; do
    # This is more complex and needs manual review, so just report files
    if grep -q "rdat\.mint(" "$file"; then
        echo "  - $file contains rdat.mint() calls that need manual update"
    fi
done

echo "Script complete. Manual review needed for rdat.mint() replacements."