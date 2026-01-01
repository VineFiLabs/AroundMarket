// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

interface IAroundError {

    error InvalidPeriod();

    error MarketAlreadyEnd();
    
    error InvalidMarketId();

    error ZeroAddress();

    error InvalidRandomNumber();

    error NotTimeYet();

    error ZeroParticipant();

    error AlreadyWithdraw();

    error AlreadyInitialize();

    error NonMultiSig();

    error InvalidState();

    error ZeroAmount();

    error InvalidOutput();

    error InsufficientBalance();

    error LiquidityWayClosed();

    error InvalidLpShare();

    error MarketClosed();

    error NotWithdrawTime();

    error TouchOracleErr();

    error TouchAroundErr();
    
}