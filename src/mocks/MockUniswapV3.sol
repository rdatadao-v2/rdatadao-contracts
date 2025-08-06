// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../interfaces/IUniswapV3.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title MockSwapRouter
 * @notice Mock implementation of Uniswap V3 SwapRouter for testing
 */
contract MockSwapRouter is ISwapRouter {
    uint256 public constant MOCK_EXCHANGE_RATE = 1e18; // 1:1 for simplicity
    
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable override returns (uint256 amountOut) {
        // Transfer tokens in
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        
        // Calculate output (1:1 ratio for mock)
        amountOut = params.amountIn;
        require(amountOut >= params.amountOutMinimum, "Too little received");
        
        // Transfer tokens out
        IERC20(params.tokenOut).transfer(params.recipient, amountOut);
        
        return amountOut;
    }
}

/**
 * @title MockNonfungiblePositionManager
 * @notice Mock implementation of Uniswap V3 Position Manager for testing
 */
contract MockNonfungiblePositionManager is ERC721, INonfungiblePositionManager {
    uint256 private _nextTokenId = 1;
    mapping(uint256 => Position) private _positions;
    
    struct Position {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }
    
    constructor() ERC721("Uniswap V3 Positions NFT-V1", "UNI-V3-POS") {}
    
    function mint(
        MintParams calldata params
    ) external payable override returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ) {
        // Transfer tokens
        IERC20(params.token0).transferFrom(msg.sender, address(this), params.amount0Desired);
        IERC20(params.token1).transferFrom(msg.sender, address(this), params.amount1Desired);
        
        // Mint NFT
        tokenId = _nextTokenId++;
        _mint(params.recipient, tokenId);
        
        // Calculate liquidity (simplified)
        liquidity = uint128(params.amount0Desired + params.amount1Desired);
        
        // Store position
        _positions[tokenId] = Position({
            token0: params.token0,
            token1: params.token1,
            fee: params.fee,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidity: liquidity
        });
        
        return (tokenId, liquidity, params.amount0Desired, params.amount1Desired);
    }
    
    // Override ownerOf from ERC721
    function ownerOf(uint256 tokenId) public view override(ERC721, INonfungiblePositionManager) returns (address) {
        return ERC721.ownerOf(tokenId);
    }
    
    // Forward safeTransferFrom - no override needed since ERC721 implements it
    
    function positions(uint256 tokenId) external view override returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    ) {
        Position memory pos = _positions[tokenId];
        return (
            0, // nonce
            address(0), // operator
            pos.token0,
            pos.token1,
            pos.fee,
            pos.tickLower,
            pos.tickUpper,
            pos.liquidity,
            0, // feeGrowthInside0LastX128
            0, // feeGrowthInside1LastX128
            0, // tokensOwed0
            0  // tokensOwed1
        );
    }
}

/**
 * @title MockUniswapV3Pool
 * @notice Mock implementation of Uniswap V3 Pool for testing
 */
contract MockUniswapV3Pool is IUniswapV3Pool {
    address private _token0;
    address private _token1;
    uint24 private _fee;
    
    constructor(address token0_, address token1_, uint24 fee_) {
        _token0 = token0_;
        _token1 = token1_;
        _fee = fee_;
    }
    
    function slot0() external pure override returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    ) {
        // Return mock values
        return (
            79228162514264337593543950336, // sqrtPriceX96 (1:1 price)
            0, // tick
            0, // observationIndex
            1, // observationCardinality
            1, // observationCardinalityNext
            0, // feeProtocol
            true // unlocked
        );
    }
    
    function token0() external view override returns (address) {
        return _token0;
    }
    
    function token1() external view override returns (address) {
        return _token1;
    }
    
    function fee() external view override returns (uint24) {
        return _fee;
    }
    
    function tickSpacing() external pure override returns (int24) {
        return 60; // Standard for 0.3% pools
    }
}

/**
 * @title MockUniswapV3Factory
 * @notice Mock implementation of Uniswap V3 Factory for testing
 */
contract MockUniswapV3Factory is IUniswapV3Factory {
    mapping(address => mapping(address => mapping(uint24 => address))) private _pools;
    
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view override returns (address pool) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return _pools[token0][token1][fee];
    }
    
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override returns (address pool) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "ZERO_ADDRESS");
        require(_pools[token0][token1][fee] == address(0), "POOL_EXISTS");
        
        pool = address(new MockUniswapV3Pool(token0, token1, fee));
        _pools[token0][token1][fee] = pool;
        
        return pool;
    }
}