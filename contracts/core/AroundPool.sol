// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IAroundPool} from "../interfaces/IAroundPool.sol";
import {IAroundPoolFactory} from "../interfaces/IAroundPoolFactory.sol";

import {IPool} from "../interfaces/aave/IPool.sol";
import {IAaveProtocolDataProvider} from "../interfaces/aave/IAaveProtocolDataProvider.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AroundPool is IAroundPool {

    using SafeERC20 for IERC20;

    uint64 private MinimumProfit = 10000;
    address public aroundPoolFactory;
    address public aroundMarket;
    address public token;
    address public relayer;
    bool public ifAllot;

    constructor(
        address thisAroundMarket,
        address thisToken,
        address thisRelayer
    ) { 
        aroundPoolFactory = msg.sender;
        aroundMarket = thisAroundMarket;
        relayer = thisRelayer;
        token= thisToken;
    }

    modifier onlyCaller {
        _checkCaller();
        _;
    }

    ReserveInfo private reserveInfo;

    function deposit(
        bool ifOpenAave,
        uint128 amountIn
    ) external onlyCaller{
        //Trade amount + liquidityFee
        reserveInfo.totalCollateralAmount += amountIn;
        if(ifOpenAave) {
            reserveInfo.lentOut += uint128(_getTokenBalance(token));
            _aaveDeposite(_getAaveInfo().pool, _getTokenBalance(token));
        }
    }

    function touch(
        bool ifEnd,
        bool ifOpenAave,
        address receiver,
        uint128 amountOut
    ) external onlyCaller {
        address pool = _getAaveInfo().pool;
        reserveInfo.totalCollateralAmount -= amountOut;
        if(ifOpenAave) {
            _aaveWithdraw(pool);
        }
        IERC20(token).safeTransfer(receiver, amountOut);
        uint256 tokenBalance = _getTokenBalance(token);
        if(ifEnd == false && ifOpenAave) {
            _aaveDeposite(pool, tokenBalance);
        }
        emit Touch(token, receiver, amountOut);
    }

    function allot(bool inValidMarket, bool ifOpenAave) external onlyCaller {
        if(ifAllot) {revert AlreadyAllot();}
        if(ifOpenAave) {
            _aaveWithdraw(_getAaveInfo().pool);
        }
        uint128 value;
        uint128 balance = uint128(_getTokenBalance(token));
        if(inValidMarket) {
            value = balance;
        }else {
            if(balance > reserveInfo.totalCollateralAmount) {
                reserveInfo.lentOut = 0;
            } else {
                reserveInfo.lentOut -= balance;
            }
        }
        if(value > 0) {
            IERC20(token).safeTransfer(relayer, value);
        }
        reserveInfo.totalCollateralAmount = balance;
        ifAllot = true;
    }

    function _aaveDeposite(address _pool, uint256 _tokenBalance) private {
        IERC20(token).approve(_pool, _tokenBalance);
        IPool(_pool).deposit(
            token, 
            _tokenBalance, 
            address(this), 
            _getAaveInfo().referralCode
        );
    }

    function _aaveWithdraw(address _pool) private {
        address aToken = _getAaveInfo().aToken;
        uint256 aTokenBalance = _getTokenBalance(aToken);
        if(aTokenBalance > 0){
            IERC20(aToken).approve(_pool, type(uint256).max);
            IPool(_pool).withdraw(token, type(uint256).max, address(this));
            IERC20(aToken).approve(_pool, 0);
        }
    }

    function _checkCaller() private view {
        require(msg.sender == aroundMarket);
    }

    function _getAaveInfo() private view returns (IAroundPoolFactory.AaveInfo memory thisAaveInfo) {
        thisAaveInfo = IAroundPoolFactory(aroundPoolFactory).getAaveInfo();
    }

    function _getTokenBalance(address thisToken) internal view returns (uint256 accountTokenBalance) {
        accountTokenBalance = IERC20(thisToken).balanceOf(address(this));
    }

    function getAavePoolPaused() public view returns (bool isPaused) {
        isPaused = IAaveProtocolDataProvider(_getAaveInfo().aaveProtocolDataProvider).getPaused(token);
    }

    function getReserveInfo() external view returns (ReserveInfo memory thisReserveInfo) {
        thisReserveInfo = reserveInfo;
    }

}