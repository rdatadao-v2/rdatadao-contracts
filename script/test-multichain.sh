#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run tests on a specific chain
run_chain_tests() {
    local chain=$1
    local profile=$2
    
    echo -e "\n${GREEN}Running tests on $chain...${NC}"
    
    # Run tests with the specific profile
    forge test --profile "$profile" -vvv
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $chain tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $chain tests failed${NC}"
        return 1
    fi
}

# Check if Anvil instances are running
check_anvil() {
    echo -e "${YELLOW}Checking Anvil instances...${NC}"
    ./script/anvil-multichain.sh status
    
    # Check if both are running
    if ! (nc -z localhost 8545 2>/dev/null && nc -z localhost 8546 2>/dev/null); then
        echo -e "\n${RED}Not all Anvil instances are running!${NC}"
        echo -e "${YELLOW}Starting Anvil instances...${NC}"
        ./script/anvil-multichain.sh start
        sleep 3
    fi
}

# Main test execution
main() {
    echo -e "${GREEN}Multi-chain Test Runner${NC}"
    echo -e "${GREEN}=======================${NC}"
    
    # Check command line arguments
    case "$1" in
        base)
            check_anvil
            run_chain_tests "Base (local)" "local-base"
            ;;
        vana)
            check_anvil
            run_chain_tests "Vana (local)" "local-vana"
            ;;
        all|"")
            check_anvil
            
            # Run tests on both chains
            echo -e "\n${GREEN}Running tests on all chains...${NC}"
            
            BASE_RESULT=0
            VANA_RESULT=0
            
            run_chain_tests "Base (local)" "local-base" || BASE_RESULT=1
            run_chain_tests "Vana (local)" "local-vana" || VANA_RESULT=1
            
            # Summary
            echo -e "\n${GREEN}Test Summary${NC}"
            echo -e "${GREEN}============${NC}"
            
            if [ $BASE_RESULT -eq 0 ]; then
                echo -e "${GREEN}✓ Base tests: PASSED${NC}"
            else
                echo -e "${RED}✗ Base tests: FAILED${NC}"
            fi
            
            if [ $VANA_RESULT -eq 0 ]; then
                echo -e "${GREEN}✓ Vana tests: PASSED${NC}"
            else
                echo -e "${RED}✗ Vana tests: FAILED${NC}"
            fi
            
            # Exit with error if any tests failed
            if [ $BASE_RESULT -ne 0 ] || [ $VANA_RESULT -ne 0 ]; then
                exit 1
            fi
            ;;
        stop)
            echo -e "${YELLOW}Stopping Anvil instances...${NC}"
            ./script/anvil-multichain.sh stop
            ;;
        *)
            echo "Usage: $0 [base|vana|all|stop]"
            echo ""
            echo "Commands:"
            echo "  base  - Run tests on local Base chain only"
            echo "  vana  - Run tests on local Vana chain only"
            echo "  all   - Run tests on both chains (default)"
            echo "  stop  - Stop all Anvil instances"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"