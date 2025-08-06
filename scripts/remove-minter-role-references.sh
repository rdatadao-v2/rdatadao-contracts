#!/bin/bash

echo "Finding and fixing MINTER_ROLE references..."

# Find all files with rdat.MINTER_ROLE() references
files_with_minter=$(grep -l "rdat\.MINTER_ROLE()" test/*.sol test/**/*.sol 2>/dev/null)

for file in $files_with_minter; do
    echo "Processing $file..."
    
    # Comment out the line with MINTER_ROLE grant
    sed -i '' 's/rdat\.grantRole(rdat\.MINTER_ROLE(), /\/\/ RDAT no longer has MINTER_ROLE - /g' "$file"
done

# Find all files with rdat.mint() calls
files_with_mint=$(grep -l "rdat\.mint(" test/*.sol test/**/*.sol 2>/dev/null)

echo ""
echo "Files that still have rdat.mint() calls that need manual review:"
for file in $files_with_mint; do
    count=$(grep -c "rdat\.mint(" "$file")
    echo "  - $file ($count occurrences)"
done

echo ""
echo "Done! Manual review needed for rdat.mint() replacements."