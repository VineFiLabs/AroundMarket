// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import {IAroundMarket} from "../interfaces/IAroundMarket.sol";
import {IAroundPoolFactory} from "../interfaces/IAroundPoolFactory.sol";
import {AroundLib} from "../libraries/AroundLib.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AroundRouter {

    using SafeERC20 for IERC20;

    address private aroundMarket;
    address private aroundPoolFactory;

    constructor(address _aroundMarket, address _aroundPoolFactory) {
        aroundMarket = _aroundMarket;
        aroundPoolFactory = _aroundPoolFactory;
    }

    struct CreateMarket {
        IAroundPoolFactory.MarketType marketType;
        uint32 period;
        uint128 expectVirtualLiquidity;
        address collateral;
        address creator;
        string quest;
    } 
    
    function createMarket(
        CreateMarket calldata params
    ) external {
        IAroundPoolFactory(aroundPoolFactory).createPool(
            params.marketType, 
            params.collateral, 
            params.creator, 
            params.quest
        );
        uint256 lastMarketId = IAroundPoolFactory(aroundPoolFactory).marketId();
        uint256 amount = AroundLib._getGuardedAmount(
            IERC20Metadata(params.collateral).decimals(),
            params.expectVirtualLiquidity,
            IAroundMarket(aroundMarket).DefaultVirtualLiquidity()
        );
        IERC20(params.collateral).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(params.collateral).approve(aroundMarket, amount);
        IAroundMarket(aroundMarket).createMarket(params.period, params.expectVirtualLiquidity, lastMarketId -1, amount);
    }

}