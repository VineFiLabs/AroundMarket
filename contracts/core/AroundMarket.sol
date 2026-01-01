// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {AroundMath} from "../libraries/AroundMath.sol";
import {AroundLib} from "../libraries/AroundLib.sol";
import {IAroundMarket} from "../interfaces/IAroundMarket.sol";
import {IAroundPool} from "../interfaces/IAroundPool.sol";
import {IAroundPoolFactory} from "../interfaces/IAroundPoolFactory.sol";
import {IEchoOptimisticOracle} from "../interfaces/IEchoOptimisticOracle.sol";
import {ILuckyPool} from "../interfaces/ILuckyPool.sol";
import {IAroundError} from "../interfaces/IAroundError.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract AroundMarket is ReentrancyGuard, IAroundMarket, IAroundError {

    using SafeERC20 for IERC20;

    uint32 private constant RATE = 100_000;
    uint32 private constant Min_Lucky_Volume = 1000;
    uint32 public DefaultVirtualLiquidity = 100_000;

    address public multiSig;
    address public feeReceiver;
    address public aroundPoolFactory;
    address public oracle;
    bool public isInitialize;

    mapping(uint256 => MarketInfo) private marketInfo;
    mapping(uint256 => LiqudityInfo) private liqudityInfo;
    mapping(address => mapping(uint256 => UserPosition)) private userPosition;
    mapping(address => mapping(uint256 => bool)) private userIfParticipateId;
    mapping(address => uint256[]) private userParticipateIds;
    mapping(uint256 => AddLiqudityShares) private addLiqudityShares;

    mapping(uint256 => mapping(uint64 => address)) public raffleTicketToUser;

    modifier onlyMultiSig {
        _checkMultiSig();
        _;
    }

    function initialize(
        address thisMultiSig, 
        address thisAroundPoolFactory, 
        address thisOracle
    ) external {
        if(isInitialize) {
            revert AlreadyInitialize();
        }
        multiSig = thisMultiSig;
        aroundPoolFactory = thisAroundPoolFactory;
        oracle = thisOracle;
        feeReceiver = multiSig;
        isInitialize = true;
    }

    function changeFeeReceiver(address newFeeReceiver) external onlyMultiSig {
        feeReceiver = newFeeReceiver;
    }

    function setInvalidMarket(uint256 thisMarketId) external onlyMultiSig {
        marketInfo[thisMarketId].result = Result.InvalidMarket;
    }

    function setMarketOpenAave(uint256 thisMarketId, bool state) external onlyMultiSig {
        marketInfo[thisMarketId].ifOpenAave = state;
    }

    function updateFinallyAmount(uint256 thisMarketId) external onlyMultiSig {
        _updateFinallyAmount(thisMarketId);
    }

    function createMarket(
        uint32 period,
        uint128 expectVirtualLiquidity,
        uint256 thisMarketId,
        uint256 amount
    ) external {
        address thisCollateral = _getPoolInfo(thisMarketId).collateral;
        uint8 decimals = _getDecimals(thisCollateral);
        uint64 currentTime = uint64(block.timestamp);
        uint64 endTime = currentTime + period;
        if(_getPoolInfo(thisMarketId).creator == address(0) && marketInfo[thisMarketId].startTime != 0) {
            revert InvalidMarketId();
        }
        if(period < 4 hours) {
            revert InvalidPeriod();
        }
        //Create market fee
        uint256 guaranteeAmount = AroundLib._getGuardedAmount(
            decimals,
            expectVirtualLiquidity,
            DefaultVirtualLiquidity
        );
        require(amount == guaranteeAmount);
        _userSafeTransfer(
            thisCollateral, 
            feeReceiver, 
            guaranteeAmount
        );

        {
            marketInfo[thisMarketId] = MarketInfo({
                result: Result.Pending,
                ifOpenAave: false,
                ifUpdateFinallyAmount: false,
                participants: 0,
                startTime: currentTime,
                endTime: endTime,
                totalRaffleTicket: 0,
                collateral: thisCollateral
            });
            liqudityInfo[thisMarketId].virtualLiquidity = uint128(expectVirtualLiquidity * 10 ** decimals);
        }
        emit CreateNewMarket(thisMarketId);
    }

    function buy(Result bet, uint128 amount, uint256 thisMarketId) external nonReentrant {
        _checkZeroAmount(amount);
        //TODO
        _checkMarketIfClosed(thisMarketId);

        _checkMarketResult(thisMarketId);
        uint16 totalFeeRate = getFeeInfo(thisMarketId).totalFee;
        uint128 netInput;
        // Transfer fund
        {   
            uint128 totalFee = amount * totalFeeRate / RATE;
            uint128 liquidityFee = _transferFee(
                totalFee,
                thisMarketId
            );
            uint128 remainAmount = amount - totalFee;
            liqudityInfo[thisMarketId].liquidityFeeAmount += liquidityFee;

            //inject aroundPool
            _injectAroundPool(
                remainAmount,
                liquidityFee,
                thisMarketId
            );
        }
        // Calculate the net input (minus handling fees)
        (netInput, ) = AroundMath._calculateNetInput(totalFeeRate, amount);
        
        // Calculate the output quantity and handling fee
        (uint256 output, ) = AroundMath._calculateBuyOutput(
            bet,
            totalFeeRate,
            amount,
            getLiqudityInfo(thisMarketId).virtualLiquidity,
            getLiqudityInfo(thisMarketId).tradeCollateralAmount + getLiqudityInfo(thisMarketId).lpCollateralAmount,
            getLiqudityInfo(thisMarketId).yesAmount,
            getLiqudityInfo(thisMarketId).noAmount
        );
        
        if(output == 0) {
            revert InvalidOutput();
        }
        
        // Update the liqudity and user 
        unchecked {
            userPosition[msg.sender][thisMarketId].volume += amount;
        }
        if (bet == IAroundMarket.Result.Yes) {
            liqudityInfo[thisMarketId].yesAmount += output;
            userPosition[msg.sender][thisMarketId].yesBalance += output;
        } else {
            liqudityInfo[thisMarketId].noAmount += output;
            userPosition[msg.sender][thisMarketId].noBalance += output;
        }
        
        //Update liqudity
        liqudityInfo[thisMarketId].tradeCollateralAmount += netInput;

        //record
        _record(thisMarketId, amount);

        //Check raffle ticket
        _updateRaffleTicket(thisMarketId);
        emit Buy(thisMarketId, msg.sender, bet, amount);
    }

    function sell(Result bet, uint256 amount, uint256 thisMarketId) external nonReentrant {
        _checkZeroAmount(amount);

        //TODO
        _checkMarketIfClosed(thisMarketId);
        uint16 totalFeeRate = getFeeInfo(thisMarketId).totalFee;
        uint128 fee;
        uint256 output;
        // Calculate the output quantity and handling fee
        (output, fee) = AroundMath._calculateSellOutput(
            bet,
            totalFeeRate,
            getLiqudityInfo(thisMarketId).virtualLiquidity,
            getLiqudityInfo(thisMarketId).tradeCollateralAmount,
            getLiqudityInfo(thisMarketId).lpCollateralAmount,
            amount,
            getLiqudityInfo(thisMarketId).yesAmount,
            getLiqudityInfo(thisMarketId).noAmount
        );
        uint128 totalValueOut = uint128(output + fee);
        unchecked {
            userPosition[msg.sender][thisMarketId].volume += totalValueOut;
        }
        
        if(getLiqudityInfo(thisMarketId).tradeCollateralAmount < totalValueOut) {
            revert InvalidOutput();
        }

        // update the user's position and liqudityInfo 
        if (bet == IAroundMarket.Result.Yes) {
            if(getUserPosition(msg.sender, thisMarketId).yesBalance < amount) {
                revert InsufficientBalance();
            }
            userPosition[msg.sender][thisMarketId].yesBalance -= amount;
            liqudityInfo[thisMarketId].yesAmount -= amount;
        } else {
            if(getUserPosition(msg.sender, thisMarketId).noBalance < amount) {
                revert InsufficientBalance();
            }
            userPosition[msg.sender][thisMarketId].noBalance -= amount;
            liqudityInfo[thisMarketId].noAmount -= amount;
        }
        
        //update
        liqudityInfo[thisMarketId].tradeCollateralAmount -= totalValueOut;

        {   
            
            (, , , uint128 liquidityFee,) = _getFeeInfo(thisMarketId, fee);
            liqudityInfo[thisMarketId].liquidityFeeAmount += liquidityFee;
            //Touch aroundPool
            _touchAroundPool(
                false,
                getMarketInfo(thisMarketId).ifOpenAave,
                totalValueOut - liquidityFee,
                _getAroundPool(thisMarketId),
                address(this)
            );
            IERC20(_getPoolInfo(thisMarketId).collateral).safeTransfer(msg.sender, output);
            if(fee > 0) {
                _transferFee(
                    fee,
                    thisMarketId
                );
            }
        }

        //record
        _record(thisMarketId, totalValueOut);

        //Check raffle ticket
        _updateRaffleTicket(thisMarketId);
        emit Sell(thisMarketId, msg.sender, bet, amount);
    }

    function addLiquidity(uint256 thisMarketId, uint128 amount) external nonReentrant {
        //TODO
        _checkMarketIfClosed(thisMarketId);
        _checkZeroAmount(amount);
        _checkMarketResult(thisMarketId);
        
        //inject aroundPool
        _injectAroundPool(
            amount,
            0,
            thisMarketId
        );
        
        // Get yes and no share
        (uint256 yesShare, uint256 noShare) = AroundMath._calculateLiquidityShares(
            IAroundMarket.Result.Pending,
            amount,
            getLiqudityInfo(thisMarketId).virtualLiquidity,
            getLiqudityInfo(thisMarketId).yesAmount,
            getLiqudityInfo(thisMarketId).noAmount
        );

        uint256 lpAmount = AroundMath._calculateSharesToMint(
            amount,
            getLiqudityInfo(thisMarketId).lpCollateralAmount + getLiqudityInfo(thisMarketId).liquidityFeeAmount,
            getLiqudityInfo(thisMarketId).totalLp
        );
        
        // Update liqudityInfo state
        liqudityInfo[thisMarketId].yesAmount += yesShare;
        liqudityInfo[thisMarketId].noAmount += noShare;
        liqudityInfo[thisMarketId].lpCollateralAmount += amount;
        liqudityInfo[thisMarketId].totalLp += lpAmount;

        //Update addLiqudityShares
        addLiqudityShares[thisMarketId].yesAmount += uint128(yesShare);
        addLiqudityShares[thisMarketId].noAmount += uint128(noShare);
        
        // Update user position
        userPosition[msg.sender][thisMarketId].lp += lpAmount;
        userPosition[msg.sender][thisMarketId].collateralAmount += amount;
        emit AddLiqudity(thisMarketId, msg.sender, amount);
    }

    // function removeLiquidity(uint256 thisMarketId, uint128 lpAmount) external nonReentrant {
    //     //TODO
    //     _checkMarketIfEnd(thisMarketId);

    //     if(lpAmount == 0 || getUserPosition(msg.sender, thisMarketId).lp < lpAmount){
    //         revert InvalidLpShare();
    //     }
    //     uint256 totalLp = getLiqudityInfo(thisMarketId).totalLp;
    //     // Calculate the due share of collateral tokens and transaction fees
    //     (uint128 collateralAmount, uint128 liquidityFeeShare) = AroundMath._calculateLiquidityWithdrawal(
    //         getLiqudityInfo(thisMarketId).liquidityFeeAmount,
    //         getUserPosition(msg.sender, thisMarketId).collateralAmount,
    //         lpAmount,
    //         getUserPosition(msg.sender, thisMarketId).lp,
    //         totalLp
    //     );
    //     _checkZeroAmount(collateralAmount + liquidityFeeShare);
        
    //     // Calculate the number of YES and NO tokens that should be reduced
    //     (uint256 yesShare, uint256 noShare) = AroundMath._calculateLiquidityShares(
    //         getMarketInfo(thisMarketId).result,
    //         lpAmount,
    //         getLiqudityInfo(thisMarketId).virtualLiquidity,
    //         getLiqudityInfo(thisMarketId).yesAmount,
    //         getLiqudityInfo(thisMarketId).noAmount
    //     );
        
    //     // Update the liquidity status
    //     liqudityInfo[thisMarketId].yesAmount -= yesShare;
    //     liqudityInfo[thisMarketId].noAmount -= noShare;
    //     liqudityInfo[thisMarketId].lpCollateralAmount -= collateralAmount;
    //     liqudityInfo[thisMarketId].totalLp -= lpAmount;
        
    //     // Update the user's position
    //     userPosition[msg.sender][thisMarketId].lp -= lpAmount;
    //     userPosition[msg.sender][thisMarketId].collateralAmount -= collateralAmount;
        
    //     // Update the balance of handling fee
    //     if (liquidityFeeShare > 0) {
    //         liqudityInfo[thisMarketId].liquidityFeeAmount -= liquidityFeeShare;
    //     }

    //     //Touch aroundPool
    //     _touchAroundPool(
    //         false,
    //         getMarketInfo(thisMarketId).ifOpenAave,
    //         collateralAmount + liquidityFeeShare,
    //         _getAroundPool(thisMarketId),
    //         msg.sender
    //     );
    //     emit RemoveLiqudity(thisMarketId, msg.sender, lpAmount);
    // }

    function touchAllot(uint256 thisMarketId) external nonReentrant {
        // _checkMarketIfEnd(thisMarketId);
        //Update result
        if(_getOracleEventState(thisMarketId) == IEchoOptimisticOracle.EventState.Yes){
            marketInfo[thisMarketId].result = Result.Yes;
        } else if(_getOracleEventState(thisMarketId) == IEchoOptimisticOracle.EventState.No) {
            marketInfo[thisMarketId].result = Result.No;
        } else {
            revert InvalidState();
        }
        bool inValidMarket;
        address aroundPool = _getAroundPool(thisMarketId);
        if(getMarketInfo(thisMarketId).result == IAroundMarket.Result.InvalidMarket) {
            inValidMarket = true;
        }
        if(getLiqudityInfo(thisMarketId).totalLp == 0) {
            liqudityInfo[thisMarketId].tradeCollateralAmount += getLiqudityInfo(thisMarketId).liquidityFeeAmount;
            liqudityInfo[thisMarketId].liquidityFeeAmount = 0;
        }
        (bool suc, ) = aroundPool.call(abi.encodeCall(
            IAroundPool(aroundPool).allot,
            (inValidMarket, getMarketInfo(thisMarketId).ifOpenAave)
        ));
        if(suc == false) {revert TouchAroundErr();}
        _updateFinallyAmount(thisMarketId);
        ILuckyPool(_getPoolInfo(thisMarketId).luckyPool).bump(thisMarketId);
    }

    function redeemWinnings(uint256 thisMarketId) external nonReentrant returns (uint256 winnings) {
        //TODO
        // _checkIfWithdrawTime(thisMarketId);

        // Calculate the token earnings
        if (getMarketInfo(thisMarketId).result == Result.Yes) {  
            if (getUserPosition(msg.sender, thisMarketId).yesBalance > 0) {
                winnings = getUserPosition(msg.sender, thisMarketId).yesBalance * getLiqudityInfo(thisMarketId).tradeCollateralAmount / 
                (getLiqudityInfo(thisMarketId).yesAmount - getAddLiqudityShares(thisMarketId).yesAmount);
            }
        } else if(getMarketInfo(thisMarketId).result == Result.No) {
            if (getUserPosition(msg.sender, thisMarketId).noBalance > 0) {
                winnings = getUserPosition(msg.sender, thisMarketId).noBalance * getLiqudityInfo(thisMarketId).tradeCollateralAmount / 
                (getLiqudityInfo(thisMarketId).noAmount - getAddLiqudityShares(thisMarketId).noAmount);
            }
        } else {
            revert InvalidState();
        }
        uint256 userLpAmount = getUserPosition(msg.sender, thisMarketId).lp;
        // Liquidity provider returns (redemption proportionally)
        if (userLpAmount > 0) {
            (uint128 collateralAmount, uint128 feeShare) = AroundMath._calculateLiquidityWithdrawal(
                getLiqudityInfo(thisMarketId).liquidityFeeAmount,
                getUserPosition(msg.sender, thisMarketId).collateralAmount,
                userLpAmount,
                userLpAmount,
                getLiqudityInfo(thisMarketId).totalLp
            );
            winnings += (collateralAmount + feeShare);
            liqudityInfo[thisMarketId].totalLp -= userLpAmount;
            liqudityInfo[thisMarketId].lpCollateralAmount -= collateralAmount;
            liqudityInfo[thisMarketId].liquidityFeeAmount -= feeShare;
        }
        
        _checkZeroAmount(winnings);
        // clear
        delete userPosition[msg.sender][thisMarketId];

        //Touch aroundPool
        _touchAroundPool(
            true,
            getMarketInfo(thisMarketId).ifOpenAave,
            uint128(winnings),
            _getAroundPool(thisMarketId),
            msg.sender
        );
        emit Release(thisMarketId, msg.sender, winnings);
    }
    
    function _updateFinallyAmount(uint256 _thisMarketId) private {
        if(getMarketInfo(_thisMarketId).ifUpdateFinallyAmount == false) {
            uint128 finallyCollateralAmount = IAroundPool(
                _getAroundPool(_thisMarketId)
            ).getReserveInfo().totalCollateralAmount;
            uint128 tradeCollateralAmount = getLiqudityInfo(_thisMarketId).tradeCollateralAmount;
            uint128 lpCollateralAmount = getLiqudityInfo(_thisMarketId).lpCollateralAmount;
            if(finallyCollateralAmount > tradeCollateralAmount + lpCollateralAmount) {
                uint128 earn = finallyCollateralAmount - lpCollateralAmount - tradeCollateralAmount;
                if(earn >= 10000) {
                    liqudityInfo[_thisMarketId].tradeCollateralAmount = tradeCollateralAmount + 
                    earn * tradeCollateralAmount / (tradeCollateralAmount + lpCollateralAmount);
                    liqudityInfo[_thisMarketId].lpCollateralAmount = lpCollateralAmount + 
                    earn * lpCollateralAmount / (tradeCollateralAmount + lpCollateralAmount);
                }else {
                    liqudityInfo[_thisMarketId].tradeCollateralAmount = tradeCollateralAmount + earn;
                }
            }else if(
                finallyCollateralAmount < tradeCollateralAmount + lpCollateralAmount && 
                finallyCollateralAmount > tradeCollateralAmount) {

                liqudityInfo[_thisMarketId].lpCollateralAmount = finallyCollateralAmount - tradeCollateralAmount;

            } else if(finallyCollateralAmount <= tradeCollateralAmount) {
                liqudityInfo[_thisMarketId].tradeCollateralAmount = finallyCollateralAmount;
                liqudityInfo[_thisMarketId].lpCollateralAmount = 0;
            }
            marketInfo[_thisMarketId].ifUpdateFinallyAmount = true;
        }
    } 

    function _transferFee(
        uint128 _totalFeeAmount,
        uint256 _thisMarketId
    ) private returns (uint128) {
        address collateral = _getPoolInfo(_thisMarketId).collateral;
        (
            uint128 oracleFee, 
            uint128 officialFee, 
            uint128 creatorFee, 
            uint128 _liquidityFee, 
            uint128 luckyFee
        ) = _getFeeInfo(_thisMarketId, _totalFeeAmount);
        if(oracleFee > 0) {
            _userSafeTransfer(collateral, oracle, oracleFee);
            IEchoOptimisticOracle(oracle).injectFee(_thisMarketId, oracleFee);
        }
        if(officialFee > 0) {
            _userSafeTransfer(collateral, feeReceiver, officialFee);
        }
        if(creatorFee > 0) {
            _userSafeTransfer(collateral, _getPoolInfo(_thisMarketId).creator, creatorFee);
        }
        if(luckyFee > 0) {
            _userSafeTransfer(collateral, _getPoolInfo(_thisMarketId).luckyPool, luckyFee);
        }
        return _liquidityFee;
    }

    function _userSafeTransfer(address _token, address _receiver, uint256 _value) private {
        IERC20(_token).safeTransferFrom(msg.sender, _receiver, _value);
    }

    function _record(uint256 _thisMarketId, uint256 _tradeAmount) private {
        if(userIfParticipateId[msg.sender][_thisMarketId] == false) {
            marketInfo[_thisMarketId].participants++;
            userParticipateIds[msg.sender].push(_thisMarketId);
            userIfParticipateId[msg.sender][_thisMarketId] = true;
        }
        unchecked {
            liqudityInfo[_thisMarketId].volume += _tradeAmount;
        }
    }

    function _updateRaffleTicket(uint256 _thisMarketId) private {
        uint8 _decimals = _getDecimals(_getPoolInfo(_thisMarketId).collateral);
        if(getUserPosition(msg.sender, _thisMarketId).volume >= Min_Lucky_Volume * 10 ** _decimals) {
            if(getUserPosition(msg.sender, _thisMarketId).raffleTicketNumber == 0){
                unchecked{
                    marketInfo[_thisMarketId].totalRaffleTicket++;
                }
                uint64 number = getMarketInfo(_thisMarketId).totalRaffleTicket;
                raffleTicketToUser[_thisMarketId][number] = msg.sender;
                userPosition[msg.sender][_thisMarketId].raffleTicketNumber = number;
            }
        }
    }

    function _injectAroundPool(
        uint128 _amountIn,
        uint128 _liquidityFee,
        uint256 _thisMarketId
    ) private {
        bool _ifOpenAave = getMarketInfo(_thisMarketId).ifOpenAave;
        address _aroundPool = _getAroundPool(_thisMarketId);
        //Transfer fund to around
        _userSafeTransfer(
            _getPoolInfo(_thisMarketId).collateral, 
            _aroundPool, 
            _amountIn + _liquidityFee
        );
        IAroundPool(_aroundPool).deposit(_ifOpenAave, _amountIn);
    }

    function _touchAroundPool(
        bool _ifEnd,
        bool _ifOpenAave,
        uint128 _amountOut,
        address _aroundPool,
        address _receiver
    ) private {
        (bool suc, ) = _aroundPool.call(abi.encodeCall(
            IAroundPool(_aroundPool).touch,
            (_ifEnd, _ifOpenAave, _receiver, _amountOut)
        ));
        if(suc == false) {revert TouchAroundErr();}
    }

    function _checkZeroAmount(uint256 _amount) private pure {
        if(_amount == 0) {
            revert ZeroAmount();
        }
    }

    function _checkMarketIfClosed(uint256 _thisMarketId) private view {
        if(block.timestamp >= getMarketInfo(_thisMarketId).endTime) {
            revert MarketClosed();
        }
    }

    function _checkMarketIfEnd(uint256 _thisMarketId) private view {
        if(block.timestamp < getMarketInfo(_thisMarketId).endTime) {
            revert MarketAlreadyEnd();
        }
    }

    function _checkIfWithdrawTime(uint256 _thisMarketId) private view {
        if(block.timestamp <= getMarketInfo(_thisMarketId).endTime + 2 hours){
            revert NotWithdrawTime();
        }
    }

    function _checkMultiSig() private view {
        if(msg.sender != multiSig) {
            revert NonMultiSig();
        }
    }

    function _checkMarketResult(uint256 _thisMarketId) private view {
        if(getMarketInfo(_thisMarketId).result == Result.InvalidMarket) {
            revert InvalidState();
        }
    }

    function _getAroundPool(uint256 _thisMarketId) private view returns (address _aroundPool) {
        _aroundPool = _getPoolInfo(_thisMarketId).aroundPool;
    }

    function _getPoolInfo(uint256 _thisMarketId) private view returns (
        IAroundPoolFactory.PoolInfo memory _thisPoolInfo
    ) {
        _thisPoolInfo = IAroundPoolFactory(aroundPoolFactory).getPoolInfo(_thisMarketId);
    }

    function _getOracleEventState(uint256 _thisMarketId) private view returns (
        IEchoOptimisticOracle.EventState _thisEventState
    ) {
        _thisEventState = IEchoOptimisticOracle(oracle).getOnlyEventState(_thisMarketId);
    }

    function _getDecimals(address _token) private view returns (uint8 _thisDecimals) {
        _thisDecimals = IERC20Metadata(_token).decimals();
    }

    function _getFeeInfo(uint256 _thisMarketId, uint128 _totalFee) internal view returns (
        uint128 _oracleFee,
        uint128 _officialFee,
        uint128 _creatorFee,
        uint128 _liquidityFee,
        uint128 _luckyFee
    ) {
        (
            _oracleFee, 
            _officialFee, 
            _creatorFee, 
            _liquidityFee, 
            _luckyFee
        ) = AroundMath._calculateFeeInfo(
            getFeeInfo(_thisMarketId),
            _totalFee
        );
    }

    function indexUserParticipateId(
        address user, 
        uint256 index
    ) external view returns (uint256 participateId) {
        participateId = userParticipateIds[user][index];
    }

    function getUserParticipateIdsLen(
        address user
    ) external view returns (uint256) {
        return userParticipateIds[user].length;
    }

    function getFeeInfo(
        uint256 thisMarketId
    ) public view returns (IAroundPoolFactory.FeeInfo memory thisFeeInfo) {
        thisFeeInfo = IAroundPoolFactory(aroundPoolFactory).getFeeInfo(thisMarketId, msg.sender);
    }

    function getUserPosition(address user, uint256 thisMarketId) public view returns (UserPosition memory thisUserPosition) {
        thisUserPosition = userPosition[user][thisMarketId];
    }

    function getMarketInfo(uint256 thisMarketId) public view returns (MarketInfo memory thisMarketInfo) {
        thisMarketInfo = marketInfo[thisMarketId];
    }

    function getLiqudityInfo(uint256 thisMarketId) public view returns (LiqudityInfo memory thisLiqudityInfo) {
        thisLiqudityInfo = liqudityInfo[thisMarketId];
    }

    function getAddLiqudityShares(uint256 thisMarketId) public view returns (AddLiqudityShares memory thisAddLiqudityShares) {
        thisAddLiqudityShares = addLiqudityShares[thisMarketId];
    }

}