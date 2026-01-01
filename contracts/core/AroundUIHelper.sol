// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IAroundMarket} from "../interfaces/IAroundMarket.sol";
import {IAroundPoolFactory} from "../interfaces/IAroundPoolFactory.sol";
import {IEchoOptimisticOracle} from "../interfaces/IEchoOptimisticOracle.sol";
import {AroundMath} from "../libraries/AroundMath.sol";
import {AroundLib} from "../libraries/AroundLib.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract AroundUIHelper {

    using SafeERC20 for IERC20;

    uint32 private DefaultVirtualLiquidity = 100_000;
    address public aroundMarket;
    address public aroundPoolFactory;
    address public echoOptimisticOracle;

    constructor(
        address _aroundMarket, 
        address _aroundPoolFactory, 
        address _echoOptimisticOracle
    ) {
        aroundMarket = _aroundMarket;
        aroundPoolFactory = _aroundPoolFactory;
        echoOptimisticOracle = _echoOptimisticOracle;
    }

    function _getPoolInfo(uint256 _thisMarketId) private view returns (IAroundPoolFactory.PoolInfo memory newPoolInfo) {
        newPoolInfo = IAroundPoolFactory(aroundPoolFactory).getPoolInfo(_thisMarketId);
    }

    function _getFeeInfo(
        uint256 _thisMarketId
    ) private view returns (IAroundPoolFactory.FeeInfo memory newFeeInfo) {
        newFeeInfo = IAroundPoolFactory(aroundPoolFactory).getFeeInfo(_thisMarketId, msg.sender);
    }

    function _getMarketInfo(uint256 _thisMarketId) private view returns (IAroundMarket.MarketInfo memory newMarketInfo) {
        newMarketInfo = IAroundMarket(aroundMarket).getMarketInfo(_thisMarketId);
    }

    function _getLiqudityInfo(uint256 _thisMarketId) private view returns (
        IAroundMarket.LiqudityInfo memory newLiqudityInfo
    ) {
        newLiqudityInfo = IAroundMarket(aroundMarket).getLiqudityInfo(_thisMarketId);
    }

    function _getUserPosition(address user, uint256 _thisMarketId) private view returns (
        IAroundMarket.UserPosition memory newMarketInfo
    ) {
        newMarketInfo = IAroundMarket(aroundMarket).getUserPosition(user, _thisMarketId);
    }

    function _getAddLiqudityShares(uint256 _thisMarketId) private view returns (
        IAroundMarket.AddLiqudityShares memory thisAddLiqudityShares
    ) {
        thisAddLiqudityShares = IAroundMarket(aroundMarket).getAddLiqudityShares(_thisMarketId);
    }

    function _getOracleInfo(uint256 thisMarketId) private view returns (
        IEchoOptimisticOracle.OracleInfo memory thisOracleInfo
    ) {
        thisOracleInfo = IEchoOptimisticOracle(echoOptimisticOracle).getOracleInfo(thisMarketId);
    }

    function _indexMarketTypeData(
        IAroundPoolFactory.MarketType _marketType, 
        uint256 _index
    ) private view returns (uint256 _thisMarketId) {
        _thisMarketId =  IAroundPoolFactory(aroundPoolFactory).indexMarketTypeData(_marketType, _index);
    }

    function getYesPrice(uint256 thisMarketId) public view returns (uint256) {
        return AroundMath._calculateYesPrice(
            _getMarketInfo(thisMarketId).result,
            _getLiqudityInfo(thisMarketId).virtualLiquidity,
            _getLiqudityInfo(thisMarketId).yesAmount,
            _getLiqudityInfo(thisMarketId).noAmount
        );
    }
    
    function getNoPrice(uint256 thisMarketId) public view returns (uint256) {
        return AroundMath._calculateNoPrice(
            _getMarketInfo(thisMarketId).result,
            _getLiqudityInfo(thisMarketId).virtualLiquidity,
            _getLiqudityInfo(thisMarketId).yesAmount,
            _getLiqudityInfo(thisMarketId).noAmount
        );
    }

    function getBuySlippage(
        uint256 thisMarketId,
        IAroundMarket.Result bet,
        uint128 amountIn
    ) public view returns (uint256) {
        return AroundMath._calculateBuySlippage(
            bet,
            _getFeeInfo(thisMarketId).totalFee,
            amountIn,
            _getLiqudityInfo(thisMarketId).virtualLiquidity,
            _getLiqudityInfo(thisMarketId).tradeCollateralAmount + _getLiqudityInfo(thisMarketId).lpCollateralAmount,
            _getLiqudityInfo(thisMarketId).yesAmount,
            _getLiqudityInfo(thisMarketId).noAmount
        );
    }

    function getSellSlippage(
        uint256 thisMarketId,
        IAroundMarket.Result bet,
        uint128 sellAmount
    ) public view returns (uint256) {
        return AroundMath._calculateSellSlippage(
            bet,
            _getLiqudityInfo(thisMarketId).virtualLiquidity,
            _getLiqudityInfo(thisMarketId).yesAmount,
            _getLiqudityInfo(thisMarketId).noAmount,
            sellAmount
        );
    }

    function getGuardedAmount(uint128 expectVirtualAmount, uint8 decimals) public view returns (uint256) {
        return AroundLib._getGuardedAmount(
            decimals,
            expectVirtualAmount,
            DefaultVirtualLiquidity
        );
    }
    
    // View liquidity value
    function getLiquidityValue(uint256 thisMarketId, address user) public view returns (uint256 totalValue) {
        if (_getUserPosition(user, thisMarketId).lp == 0) return 0;
        
        return AroundMath._calculateLiquidityValue(
            _getLiqudityInfo(thisMarketId).virtualLiquidity,
            _getLiqudityInfo(thisMarketId).liquidityFeeAmount,
            _getUserPosition(user, thisMarketId).lp,
            _getLiqudityInfo(thisMarketId).totalLp,
            _getLiqudityInfo(thisMarketId).yesAmount,
            _getLiqudityInfo(thisMarketId).noAmount
        );
    }
    
    // Estimated removal of liquidity
    function getLiquidityRemoval(uint256 thisMarketId, uint256 lpAmount) public view returns (
        uint128 collateralAmount, 
        uint128 feeShare,
        uint256 totalValue
    ) {
        require(lpAmount <= _getUserPosition(msg.sender, thisMarketId).lp, "Invalid lpAmount");
        
        (collateralAmount, feeShare) = AroundMath._calculateLiquidityWithdrawal(
            _getLiqudityInfo(thisMarketId).liquidityFeeAmount,
            _getUserPosition(msg.sender, thisMarketId).collateralAmount,
            lpAmount,
            _getUserPosition(msg.sender, thisMarketId).lp,
            _getLiqudityInfo(thisMarketId).totalLp
        );
        
        totalValue = collateralAmount + feeShare;
    }

    function getLiquidityShares(
        uint256 thisMarketId, 
        uint128 value
    ) public view returns (uint256 yesShare, uint256 noShare) {
        (yesShare, noShare) = AroundMath._calculateLiquidityShares(
            _getMarketInfo(thisMarketId).result,
            value,
            _getLiqudityInfo(thisMarketId).virtualLiquidity,
            _getLiqudityInfo(thisMarketId).yesAmount,
            _getLiqudityInfo(thisMarketId).noAmount
        );
    }

    function getLpSharesToMint(
        uint256 thisMarketId, 
        uint128 value
    ) public view returns (uint256) {
        return AroundMath._calculateSharesToMint(
            value,
            _getLiqudityInfo(thisMarketId).lpCollateralAmount + _getLiqudityInfo(thisMarketId).liquidityFeeAmount,
            _getLiqudityInfo(thisMarketId).totalLp
        );
    }

    function getBuyOutput(
        IAroundMarket.Result bet,
        uint128 buyCollateralAmount,
        uint256 thisMarketId
    ) public view returns (uint256 output, uint128 fee) {
        (output, fee) = AroundMath._calculateBuyOutput(
            bet,
            _getFeeInfo(thisMarketId).totalFee,
            buyCollateralAmount,
            _getLiqudityInfo(thisMarketId).virtualLiquidity,
            _getLiqudityInfo(thisMarketId).tradeCollateralAmount + _getLiqudityInfo(thisMarketId).lpCollateralAmount,
            _getLiqudityInfo(thisMarketId).yesAmount,
            _getLiqudityInfo(thisMarketId).noAmount
        );
    }

    function getSellOutput(
        IAroundMarket.Result bet,
        uint128 sellShareAmount,
        uint256 thisMarketId
    ) public view returns (uint256 output, uint128 fee) {
        (output, fee) = AroundMath._calculateSellOutput(
            bet,
            _getFeeInfo(thisMarketId).totalFee,
            _getLiqudityInfo(thisMarketId).virtualLiquidity,
            _getLiqudityInfo(thisMarketId).tradeCollateralAmount,
            _getLiqudityInfo(thisMarketId).lpCollateralAmount,
            sellShareAmount,
            _getLiqudityInfo(thisMarketId).yesAmount,
            _getLiqudityInfo(thisMarketId).noAmount
        );
    }

    function estimateWinAmount(
        IAroundMarket.Result bet,
        uint128 amountIn,
        uint256 thisMarketId
    ) external view returns (uint256 winnings) {
        (uint256 output, uint128 fee ) = getBuyOutput(
            bet,
            amountIn,
            thisMarketId
        );
        uint256 validCollateralAmount = 
        _getLiqudityInfo(thisMarketId).tradeCollateralAmount + amountIn - fee;
        if(bet == IAroundMarket.Result.Yes) {
            winnings = output * validCollateralAmount / 
            (_getLiqudityInfo(thisMarketId).yesAmount + output - _getAddLiqudityShares(thisMarketId).yesAmount);
        }else if(bet == IAroundMarket.Result.No){
            winnings = output * validCollateralAmount / 
            (_getLiqudityInfo(thisMarketId).noAmount + output - _getAddLiqudityShares(thisMarketId).noAmount);
        }
    }

    function indexMarketData(uint256 thisMarketId) external view returns (
        IAroundPoolFactory.PoolInfo memory thisPoolInfo,
        IAroundPoolFactory.FeeInfo memory thisFeeInfo,
        IAroundMarket.MarketInfo memory thisMarketInfo,
        IAroundMarket.LiqudityInfo memory thisLiqudityInfo,
        IEchoOptimisticOracle.OracleInfo memory thisOracleInfo,
        uint256 thisYesPrice,
        uint256 thisNoPrice
    ) {
        thisPoolInfo = _getPoolInfo(thisMarketId);
        thisFeeInfo = _getFeeInfo(thisMarketId);
        thisMarketInfo = _getMarketInfo(thisMarketId);
        thisLiqudityInfo = _getLiqudityInfo(thisMarketId);
        thisOracleInfo = IEchoOptimisticOracle(echoOptimisticOracle).getOracleInfo(thisMarketId);
        thisYesPrice = getYesPrice(thisMarketId);
        thisNoPrice = getNoPrice(thisMarketId);
    }

    /**
     * @dev Used to obtain the UI pages of all markets
     * @notice size <= 10 && size !=0
     * @param index Index page number
     * @param size Page size
     * @return poolInfoGroup PoolInfo array
     * @return marketInfoGroup MarketInfo array
     * @return liqudityInfoGroup LiqudityInfo array
     * @return oracleInfo OracleInfo array
     * @return yesPriceGroup YesPrice array
     * @return noPriceGroup NoPrice array
     */
    function batchIndexMarketData(
        uint256 index, 
        uint256 size
    ) external view returns (
        IAroundPoolFactory.PoolInfo[] memory poolInfoGroup,
        IAroundMarket.MarketInfo[] memory marketInfoGroup,
        IAroundMarket.LiqudityInfo[] memory liqudityInfoGroup,
        IEchoOptimisticOracle.OracleInfo[] memory oracleInfo,
        uint256[] memory yesPriceGroup,
        uint256[] memory noPriceGroup
    ){  
        uint256 marketId = IAroundPoolFactory(aroundPoolFactory).marketId();
        require(size <= 10 && size > 0  && index * size <= marketId, "Index overflow");
        uint256 currentId;
        uint256 len;
        if(size > marketId) {
            len = marketId;
        }else {
            if(marketId > size * (index + 1)){
                len = size;
            }else {
                len = marketId % size;
            }
            if(index != 0){
                currentId = index * size;
            }
        }
        poolInfoGroup = new IAroundPoolFactory.PoolInfo[](len);
        marketInfoGroup = new IAroundMarket.MarketInfo[](len);
        liqudityInfoGroup = new IAroundMarket.LiqudityInfo[](len);
        oracleInfo = new IEchoOptimisticOracle.OracleInfo[](len);
        yesPriceGroup = new uint256[](len);
        noPriceGroup = new uint256[](len);
        unchecked{
            for(uint256 i; i<len; i++) {
                poolInfoGroup[i] = _getPoolInfo(currentId);
                marketInfoGroup[i] = _getMarketInfo(currentId);
                liqudityInfoGroup[i] = _getLiqudityInfo(currentId);
                oracleInfo[i] = _getOracleInfo(currentId);
                yesPriceGroup[i] = getYesPrice(currentId);
                noPriceGroup[i] = getNoPrice(currentId);
                currentId++;
            }
        }
    }

    function batchIndexMarketTypeData(
        IAroundPoolFactory.MarketType marketType,
        uint256 index, 
        uint256 size
    ) external view returns (
        IAroundPoolFactory.PoolInfo[] memory poolInfoGroup,
        IAroundMarket.MarketInfo[] memory marketInfoGroup,
        IAroundMarket.LiqudityInfo[] memory liqudityInfoGroup,
        uint256[] memory yesPriceGroup,
        uint256[] memory noPriceGroup
    ) {
        uint256 marketTypeLen = IAroundPoolFactory(aroundPoolFactory).getMarketGroupLength(marketType);
        require(size <= 10 && size > 0  && index * size <= marketTypeLen);
        uint256 currentLocation;
        uint256 len;
        if(size > marketTypeLen) {
            len = marketTypeLen;
        }else {
            if(marketTypeLen > size * (index + 1)){
                len = size;
            }else {
                len = marketTypeLen % size;
            }
            if(index != 0){
                currentLocation = index * size;
            }
        }
        poolInfoGroup = new IAroundPoolFactory.PoolInfo[](len);
        marketInfoGroup = new IAroundMarket.MarketInfo[](len);
        liqudityInfoGroup = new IAroundMarket.LiqudityInfo[](len);
        yesPriceGroup = new uint256[](len);
        noPriceGroup = new uint256[](len);
        unchecked {
            for(uint256 i; i<len; i++) {
                uint256 currentId = _indexMarketTypeData(marketType, currentLocation);
                poolInfoGroup[i] = _getPoolInfo(currentId);
                marketInfoGroup[i] = _getMarketInfo(currentId);
                liqudityInfoGroup[i] = _getLiqudityInfo(currentId);
                yesPriceGroup[i] = getYesPrice(currentId);
                noPriceGroup[i] = getNoPrice(currentId);
                currentLocation++;
            }
        }
    }

    function batchIndexUserParticipateIdsInfo(
        address user,
        uint256 index, 
        uint256 size
    ) external view returns (
        uint256[] memory idGroup,
        IAroundMarket.UserPosition[] memory userPositionGroup
    ) {
        uint256 participateLen = IAroundMarket(aroundMarket).getUserParticipateIdsLen(user);
        require(size <= 10 && size > 0  && index * size <= participateLen);
        uint256 currentLocation;
        uint256 len;
        if(size > participateLen) {
            len = participateLen;
        }else {
            if(participateLen > size * (index + 1)){
                len = size;
            }else {
                len = participateLen % size;
            }
            if(index != 0){
                currentLocation = index * size;
            }
        }
        idGroup = new uint256[](len);
        userPositionGroup = new IAroundMarket.UserPosition[](len);
        unchecked{
            for(uint256 i; i<len; i++) {
                idGroup[i] = IAroundMarket(aroundMarket).indexUserParticipateId(user, currentLocation);
                userPositionGroup[i] = _getUserPosition(user, currentLocation);
                currentLocation++;
            }
        }
    }

    function getDecimals(address token) public view returns (uint8) {
        return IERC20Metadata(token).decimals();
    }

    function getTokenBalance(address token, address addr) public view returns (uint256) {
        return IERC20(token).balanceOf(addr);
    }
}