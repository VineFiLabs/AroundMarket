// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

interface IAroundPool {

    error AlreadyAllot();

    struct ReserveInfo {
        uint128 lentOut;
        uint128 totalCollateralAmount;
    }

    event Touch(address indexed thisToken, address indexed thisReceiver, uint256 indexed thisAmount);

    function getAavePoolPaused() external view returns (bool isPaused);

    function getReserveInfo() external view returns (ReserveInfo memory);

    function deposit(
        bool ifOpenAave,
        uint128 amountIn
    ) external;

    function touch(
        bool ifEnd,
        bool ifOpenAave,
        address receiver,
        uint128 amountOut
    ) external;

    function allot(bool inValidMarket, bool ifOpenAave) external;

}