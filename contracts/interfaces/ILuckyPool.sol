// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

interface ILuckyPool {

    event WithdrawReward(
        address indexed sender,
        address indexed luckyUser,
        uint256 indexed value
    );

    function luckyNumber() external view returns (uint64);

    function luckyWinner() external view returns (address);

    function ifWithdraw() external view returns (bool);

    function bump(uint256 thisMarketId) external;
}
