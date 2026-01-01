// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {ILuckyPool} from "../interfaces/ILuckyPool.sol";
import {IAroundMarket} from "../interfaces/IAroundMarket.sol";
import {IEchoOptimisticOracle} from "../interfaces/IEchoOptimisticOracle.sol";
import {IAroundError} from "../interfaces/IAroundError.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LuckyPool is ILuckyPool, IAroundError {

    using SafeERC20 for IERC20;
    
    uint64 public luckyNumber;
    address public luckyWinner;
    address public relayer;

    address private aroundPoolFactory;
    address private aroundMarket;
    bool public ifWithdraw;

    constructor(
        address thisAroundMarket,
        address thisRelayer
    ) { 
        aroundPoolFactory = msg.sender;
        aroundMarket = thisAroundMarket;
        relayer = thisRelayer;
    }

    function bump(uint256 thisMarketId) external {
        if(ifWithdraw) {
            revert AlreadyWithdraw();
        }
        uint64 participants = IAroundMarket(aroundMarket).getMarketInfo(thisMarketId).totalRaffleTicket;
        uint64 endTime = IAroundMarket(aroundMarket).getMarketInfo(thisMarketId).endTime;
        // if(block.timestamp < endTime + 2 hours) {
        //     revert NotTimeYet();
        // }
        address collateral = IAroundMarket(aroundMarket).getMarketInfo(thisMarketId).collateral;
        uint256 winnerReward = IERC20(collateral).balanceOf(address(this));
        if(winnerReward > 0) {
            if(participants == 0) {
                IERC20(collateral).safeTransfer(relayer, winnerReward);
            }else {
                address oracle = IAroundMarket(aroundMarket).oracle();
                uint64 oracleRandomNumber = IEchoOptimisticOracle(oracle).getOracleInfo(thisMarketId).randomNumber;
                if(oracleRandomNumber == 0) {
                    revert InvalidRandomNumber();
                }
                _selectLuckyWinner(oracleRandomNumber, participants, collateral, winnerReward, thisMarketId);
            }
            ifWithdraw = true;
        }
    }
    
    function _selectLuckyWinner(
        uint64 _oracleRandomNumber, 
        uint64 _totalUser,
        address _collateral,
        uint256 _winnerReward,
        uint256 _thisMarketId
    ) internal {
        luckyNumber = uint64(_getLuckyRandomNumber(_oracleRandomNumber, _totalUser));
        if(_collateral == address(0)){
            revert ZeroAddress();
        }
        luckyWinner = IAroundMarket(aroundMarket).raffleTicketToUser(_thisMarketId, luckyNumber);
        if(luckyWinner == address(0)){
            revert ZeroAddress();
        }
        IERC20(_collateral).safeTransfer(luckyWinner, _winnerReward);
        emit WithdrawReward(msg.sender, luckyWinner, _winnerReward);
    }
    
    function _getLuckyRandomNumber(uint64 _oracleRandomNumber, uint64 _totalUser) internal view returns (uint256 thisLuckyNumber) {
        if(_totalUser == 1) {
            thisLuckyNumber = 1;
        } else {
            thisLuckyNumber = uint256(keccak256(abi.encodePacked(
                _oracleRandomNumber,
                block.timestamp,
                _totalUser
            ))) % _totalUser;
            if(thisLuckyNumber == 0) {
                thisLuckyNumber = _totalUser;
            }
        }
    }
    
}