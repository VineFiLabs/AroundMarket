// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

interface IAroundPoolFactory {

    error AlreadyInitialize();
    error InvalidToken();
    error InvalidQuest();

    enum MarketType{Other, Crypto, Sport, Game, Politics, Economy, Tech, Weather}

    /******************************Struct************************************** */

    struct MarketPlace{
        MarketType marketType;
        uint256 place;
    }

    struct PoolInfo {
        address collateral;
        address aroundPool;
        address luckyPool;
        address creator;
        string quest;
    }

    struct TokenInfo {
        bool valid;
        uint128 createFeeAmount;
    }

    struct FeeInfo {
        uint16 officialFee;
        uint16 luckyFee;
        uint16 oracleFee;
        uint16 creatorFee;
        uint16 liquidityFee;
        uint16 totalFee;
    }

    struct AaveInfo {
        uint16 referralCode;
        address pool;
        address aToken;
        address aaveProtocolDataProvider;
    }

    /******************************Read************************************** */
    function marketId() external view returns (uint256);

    function initialize(address _aroundMarket, address _oracle) external;

    function getTokenInfo(address token) external view returns (TokenInfo memory thisTokenInfo);

    function getPoolInfo(uint256 thisMarketId) external view returns (PoolInfo memory thisPoolInfo);

    function getAaveInfo() external view returns (AaveInfo memory thisAaveInfo);

    function indexMarketTypeData(MarketType marketType, uint256 index) external view returns (uint256);

    function getMarketGroupLength(MarketType marketType) external view returns (uint256);

    function getMarketPlace(uint256 id) external view returns (MarketPlace memory);

    function getFeeInfo(
        uint256 thisMarketId, 
        address elfHolder
    ) external view returns (FeeInfo memory thisFeeInfo);

    /******************************Write************************************** */
    function createPool(
        MarketType marketType,
        address collateral,
        address thisCreator,
        string calldata quest
    ) external;
}