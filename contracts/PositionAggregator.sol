pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import './interfaces/INonfungiblePositionManager.sol';
import './libraries/PoolAddress.sol';

/// @title NFT positions
/// @notice Provides utility function for reading an accounts Uniswap V3 positions
contract PositionAggregator {

  // details about the uniswap position
  struct Position {
    TokenMetadata token0;
    TokenMetadata token1;
    // the index of the NFT position
    uint256 tokenId;
    uint24 fee;
    // the ID of the pool with which this token is connected
    uint80 poolId;
    // the tick range of the position
    int24 tickLower;
    int24 tickUpper;
    // the liquidity of the position
    uint128 liquidity;
    // the fee growth of the aggregate position as of the last action on the individual position
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
    // how many uncollected tokens are owed to the position, as of the last computation
    uint128 tokensOwed0;
    uint128 tokensOwed1;
    uint160 sqrtPriceX96;
    int24 tick;
  }

  // data relevant to a position's pool
  struct PoolData {
    uint160 sqrtPriceX96;
    int24 tick;
  }

  struct TokenMetadata {
    address contractAddress;
    string name;
    string symbol;
    uint8 decimals;
  }

  /// @dev The address of the nonfungible position manager contract
  address private immutable _positionManager;

  /// @dev The address of the Uniswap V3 factory
  address private immutable _factory;

  constructor(address _positionManager_, address _factory_) {
    _positionManager = _positionManager_;
    _factory = _factory_;
  }

  function getTokenMeta(address contractAddress) public view returns (TokenMetadata memory) {
    ERC20 tokenContract = ERC20(contractAddress);
    return TokenMetadata({
      contractAddress: contractAddress,
      name: tokenContract.name(),
      symbol: tokenContract.symbol(),
      decimals: tokenContract.decimals()
    });
  }

  function getPoolData(address token0, address token1, uint24 fee) private view returns (PoolData memory) {
    PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({ token0: token0, token1: token1, fee: fee });
    IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(_factory, poolKey));
    (
      uint160 sqrtPriceX96,
      int24 tick,
      ,
      ,
      ,
      ,
    ) = pool.slot0();

    return PoolData({sqrtPriceX96: sqrtPriceX96, tick: tick});
  }

  function getPosition(uint256 tokenId) private view returns (Position memory) {
    (
      ,
      ,
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
    ) = INonfungiblePositionManager(_positionManager).positions(tokenId);

    PoolData memory poolData = getPoolData(token0, token1, fee);

    Position memory pos = Position({
      token0: getTokenMeta(token0),
      token1: getTokenMeta(token1),
      tokenId: tokenId,
      fee: fee,
      poolId: 0,
      tickLower: tickLower,
      tickUpper: tickUpper,
      liquidity: liquidity,
      feeGrowthInside0LastX128: feeGrowthInside0LastX128,
      feeGrowthInside1LastX128: feeGrowthInside1LastX128,
      tokensOwed0: tokensOwed0,
      tokensOwed1: tokensOwed1,
      sqrtPriceX96: poolData.sqrtPriceX96,
      tick: poolData.tick
    });

    return pos;
  }

  function positions(address owner) external view returns (Position[] memory) {
    INonfungiblePositionManager manager = INonfungiblePositionManager(_positionManager);
    uint256 balance = manager.balanceOf(owner);

    Position[] memory _positions = new Position[](balance);

    for (uint256 i = 0; i < balance; i++) {
      uint256 tokenId = manager.tokenOfOwnerByIndex(owner, i);
      _positions[i] = getPosition(tokenId);
    }
    return _positions;
  }
}
