#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BASE_PORT=8545
VANA_PORT=8546
BASE_CHAIN_ID=8453
VANA_CHAIN_ID=1480

# PID file locations
PID_DIR=".anvil-pids"
BASE_PID_FILE="$PID_DIR/base.pid"
VANA_PID_FILE="$PID_DIR/vana.pid"

# Create PID directory if it doesn't exist
mkdir -p "$PID_DIR"

# Function to start an Anvil instance
start_anvil() {
    local name=$1
    local port=$2
    local chain_id=$3
    local pid_file=$4
    
    # Check if already running
    if [ -f "$pid_file" ] && ps -p $(cat "$pid_file") > /dev/null 2>&1; then
        echo -e "${YELLOW}$name Anvil is already running on port $port${NC}"
        return
    fi
    
    echo -e "${GREEN}Starting $name Anvil on port $port with chain ID $chain_id...${NC}"
    
    # Start Anvil in background
    anvil \
        --port "$port" \
        --chain-id "$chain_id" \
        --block-time 1 \
        --accounts 10 \
        --balance 10000 \
        --mnemonic "test test test test test test test test test test test junk" \
        > "$PID_DIR/$name.log" 2>&1 &
    
    # Save PID
    echo $! > "$pid_file"
    
    # Wait a moment for Anvil to start
    sleep 2
    
    # Check if started successfully
    if ps -p $(cat "$pid_file") > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $name Anvil started successfully${NC}"
        echo -e "  RPC URL: http://localhost:$port"
        echo -e "  Chain ID: $chain_id"
        echo -e "  Log file: $PID_DIR/$name.log"
    else
        echo -e "${RED}✗ Failed to start $name Anvil${NC}"
        rm -f "$pid_file"
    fi
}

# Function to stop an Anvil instance
stop_anvil() {
    local name=$1
    local pid_file=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${YELLOW}Stopping $name Anvil (PID: $pid)...${NC}"
            kill "$pid"
            rm -f "$pid_file"
            echo -e "${GREEN}✓ $name Anvil stopped${NC}"
        else
            echo -e "${YELLOW}$name Anvil is not running${NC}"
            rm -f "$pid_file"
        fi
    else
        echo -e "${YELLOW}$name Anvil is not running${NC}"
    fi
}

# Function to check status
check_status() {
    local name=$1
    local port=$2
    local pid_file=$3
    
    if [ -f "$pid_file" ] && ps -p $(cat "$pid_file") > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $name Anvil is running on port $port${NC}"
    else
        echo -e "${RED}✗ $name Anvil is not running${NC}"
    fi
}

# Main command handling
case "$1" in
    start)
        echo -e "${GREEN}Starting multi-chain Anvil setup...${NC}"
        start_anvil "Base" "$BASE_PORT" "$BASE_CHAIN_ID" "$BASE_PID_FILE"
        start_anvil "Vana" "$VANA_PORT" "$VANA_CHAIN_ID" "$VANA_PID_FILE"
        echo -e "\n${GREEN}Multi-chain setup complete!${NC}"
        echo -e "\nExport these environment variables for testing:"
        echo -e "${YELLOW}export LOCAL_BASE_RPC_URL=http://localhost:$BASE_PORT${NC}"
        echo -e "${YELLOW}export LOCAL_VANA_RPC_URL=http://localhost:$VANA_PORT${NC}"
        ;;
    stop)
        echo -e "${RED}Stopping all Anvil instances...${NC}"
        stop_anvil "Base" "$BASE_PID_FILE"
        stop_anvil "Vana" "$VANA_PID_FILE"
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        echo -e "${GREEN}Anvil Status:${NC}"
        check_status "Base" "$BASE_PORT" "$BASE_PID_FILE"
        check_status "Vana" "$VANA_PORT" "$VANA_PID_FILE"
        ;;
    logs)
        if [ "$2" == "base" ]; then
            if [ -f "$PID_DIR/Base.log" ]; then
                tail -f "$PID_DIR/Base.log"
            else
                echo -e "${RED}Base log file not found${NC}"
            fi
        elif [ "$2" == "vana" ]; then
            if [ -f "$PID_DIR/Vana.log" ]; then
                tail -f "$PID_DIR/Vana.log"
            else
                echo -e "${RED}Vana log file not found${NC}"
            fi
        else
            echo "Usage: $0 logs [base|vana]"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start    - Start both Base and Vana Anvil instances"
        echo "  stop     - Stop all Anvil instances"
        echo "  restart  - Restart all Anvil instances"
        echo "  status   - Check status of Anvil instances"
        echo "  logs     - View logs (e.g., $0 logs base)"
        exit 1
        ;;
esac