// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

library AroundLib {

    uint256 private constant Max_Virtual = 100_000_000;

    error InvalidVirtualAmount();

    function _getGuardedAmount(
        uint8 _thisDecimals, 
        uint128 _expectVirtualAmount,
        uint128 _currentVirtualAmount
    ) internal pure returns (uint256 _amountOut) {
        if (_expectVirtualAmount == _currentVirtualAmount) {
            _amountOut = 10 * 10 ** _thisDecimals;
        }else if(_expectVirtualAmount > _currentVirtualAmount && _expectVirtualAmount <= Max_Virtual) {
             _amountOut = 10 * (_expectVirtualAmount / _currentVirtualAmount + 1) * 10 ** _thisDecimals;
        }else {
            revert InvalidVirtualAmount();
        }
    }
}