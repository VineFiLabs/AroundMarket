// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

interface IAroundMarket {

    enum Result{Pending, Yes, No, InvalidMarket}

    /*********************************Struct****************************************** */

    struct MarketInfo{
        Result result;
        bool ifOpenAave;
        bool ifUpdateFinallyAmount;
        uint64 participants;
        uint64 startTime;
        uint64 endTime;
        address collateral;
        uint64 totalRaffleTicket;
    }

    struct LiqudityInfo {
        uint128 virtualLiquidity;
        uint128 tradeCollateralAmount;
        uint128 lpCollateralAmount;
        uint128 liquidityFeeAmount;
        uint256 totalLp;
        uint256 yesAmount;
        uint256 noAmount;
        uint256 volume;
    }

    struct AddLiqudityShares {
        uint128 yesAmount;
        uint128 noAmount;
    }

    struct UserPosition {
        uint64 raffleTicketNumber;
        uint128 collateralAmount;
        uint256 yesBalance;
        uint256 noBalance;
        uint256 lp;
        uint256 volume;
    }

    /*********************************Event****************************************** */
    event CreateNewMarket(uint256 thisNewMarketId);
    event Buy(uint256 thisMarketId, address buyer, Result bet, uint256 value);
    event Sell(uint256 thisMarketId, address seller, Result bet, uint256 amount);
    event AddLiqudity(uint256 thisMarketId, address lpProvider, uint256 value);
    event RemoveLiqudity(uint256 thisMarketId, address lpProvider, uint256 lpAmount);
    event Release(uint256 thisMarketId, address user, uint256 value);

    /*********************************Read****************************************** */
    function DefaultVirtualLiquidity() external view returns (uint32);
    function multiSig() external view returns (address);
    function feeReceiver() external view returns (address);
    function oracle() external view returns (address);
    function isInitialize() external view returns (bool);

    function raffleTicketToUser(uint256, uint64) external view returns (address);

    function getUserPosition(
        address user, 
        uint256 thisMarketId
    ) external view returns (UserPosition memory thisUserPosition);

    function indexUserParticipateId(
        address user, 
        uint256 index
    ) external view returns (uint256 participateId);

    function getUserParticipateIdsLen(
        address user
    ) external view returns (uint256);

    function getMarketInfo(uint256 thisMarketId) external view returns (MarketInfo memory thisMarketInfo);

    function getLiqudityInfo(uint256 thisMarketId) external view returns (LiqudityInfo memory thisLiqudityInfo);

    function getAddLiqudityShares(uint256 thisMarketId) external view returns (AddLiqudityShares memory thisAddLiqudityShares);

    /*********************************Write****************************************** */

    function initialize(
        address thisMultiSig, 
        address thisAroundPoolFactory, 
        address thisOracle
    ) external;
    function changeFeeReceiver(address newFeeReceiver) external;
    function setInvalidMarket(uint256 thisMarketId) external;
    function setMarketOpenAave(uint256 thisMarketId, bool state) external;

    function createMarket(
        uint32 period,
        uint128 expectVirtualLiquidity,
        uint256 thisMarketId,
        uint256 guaranteeAmount
    ) external;

    function buy(Result bet, uint128 amount, uint256 thisMarketId) external;

    function sell(Result bet, uint256 amount, uint256 thisMarketId) external;

    function addLiquidity(uint256 thisMarketId, uint128 amount) external;

    // function removeLiquidity(uint256 thisMarketId, uint128 lpAmount) external;

    function touchAllot(uint256 thisMarketId) external;

    function redeemWinnings(uint256 thisMarketId) external returns (uint256 winnings);
    
}