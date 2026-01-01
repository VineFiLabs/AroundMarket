// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

import "./AroundPool.sol";
import "./LuckyPool.sol";
import {IAroundPoolFactory} from "../interfaces/IAroundPoolFactory.sol";
import {IEchoOptimisticOracle} from "../interfaces/IEchoOptimisticOracle.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AroundPoolFactory is Ownable, IAroundPoolFactory {

    using SafeERC20 for IERC20;

    uint16 private DefaultOfficialFee = 200;
    uint16 private DefaultLiquidityFee = 150;
    uint16 private DefaultOracleFee = 75;
    uint16 private DefaultLuckyFee = 100;
    uint16 private DefaultCreatorFee = 75;
    uint16 private DefaultTotalFee = 600;

    address public aroundMarket;
    address public elf;
    address public oracle;
    address public receiver;
    bool public isInitialize;

    uint256 public marketId;

    AaveInfo private aaveInfo;

    constructor()Ownable(msg.sender){
        receiver = msg.sender;
    }

    mapping(uint256 => PoolInfo) private poolInfo;
    mapping(address => TokenInfo) private tokenInfo;
    mapping(MarketType => uint256[]) private marketTypeGroup;
    mapping(uint256 => MarketPlace) private marketPlace;
    mapping(uint256 => FeeInfo) private feeInfo;

    function initialize(address _aroundMarket, address _oracle) external onlyOwner {
        if(isInitialize) {
            revert AlreadyInitialize();
        }
        aroundMarket = _aroundMarket;
        oracle = _oracle;
        isInitialize = true;
    }

    function setElf(address thisElf) external onlyOwner {
        elf = thisElf;
    }

    function setReceiver(address thisReceiver) external onlyOwner {
        receiver = thisReceiver;
    }

    function setTokenInfo(
        address token, 
        bool state,
        uint128 amount
    ) external onlyOwner {
        tokenInfo[token] = TokenInfo({
            valid: state,
            createFeeAmount: amount
        });
    }

    function changeBaseFee(
        uint16 officialFee,
        uint16 liquidityFee,
        uint16 oracleFee,
        uint16 luckyFee,
        uint16 creatorFee
    ) external onlyOwner {
        DefaultOfficialFee = officialFee;
        DefaultLuckyFee = luckyFee;
        DefaultOracleFee = oracleFee;
        DefaultCreatorFee = creatorFee;
        DefaultLiquidityFee = liquidityFee;
        DefaultTotalFee = DefaultOfficialFee + DefaultLuckyFee + 
        DefaultOracleFee + DefaultCreatorFee + DefaultLiquidityFee;
    }

    function changeMarketType(uint256 id, MarketType newMarketType) external onlyOwner {
        MarketType oldMarketType = getMarketPlace(id).marketType;
        //Update lastest to thisId
        marketTypeGroup[oldMarketType][getMarketPlace(id).place] = 
        marketTypeGroup[oldMarketType][getMarketGroupLength(oldMarketType)];
        delete marketTypeGroup[oldMarketType][getMarketGroupLength(oldMarketType)];

        //Update newMarketType info
        marketPlace[id].marketType = newMarketType;
        marketTypeGroup[newMarketType].push(id);
        marketPlace[id].place = getMarketGroupLength(newMarketType);
    }

    function setAaveInfo(
        uint16 newReferralCode,
        address thisPool,
        address thisAToken,
        address thisAaveProtocolDataProvider
    ) external onlyOwner {
        aaveInfo.pool = thisPool;
        aaveInfo.aToken = thisAToken;
        aaveInfo.aaveProtocolDataProvider = thisAaveProtocolDataProvider;
        aaveInfo.referralCode = newReferralCode;
    }

    function createPool(
        MarketType marketType,
        address collateral,
        address thisCreator,
        string calldata quest
    ) external {
        if(bytes(quest).length > 1000) {
            revert InvalidQuest();
        }
        if(tokenInfo[collateral].valid == false) {
            revert InvalidToken();
        }
        
        feeInfo[marketId] = FeeInfo({
            officialFee: DefaultOfficialFee,
            luckyFee: DefaultLiquidityFee,
            oracleFee: DefaultOracleFee,
            liquidityFee: DefaultLuckyFee,
            creatorFee: DefaultCreatorFee,
            totalFee: DefaultTotalFee
        });
        //AroundPool
        address newAroundPool = address(
            new AroundPool{
                salt: keccak256(abi.encodePacked(marketId, msg.sender, block.chainid))
            }(aroundMarket, collateral, receiver)
        );
        //LuckyPool
        address newLuckyPool = address(
            new LuckyPool{
                salt: keccak256(abi.encodePacked(marketId, msg.sender, block.chainid))
            }(aroundMarket, receiver)
        );
        poolInfo[marketId].collateral = collateral;
        poolInfo[marketId].aroundPool = newAroundPool;
        poolInfo[marketId].luckyPool = newLuckyPool;
        poolInfo[marketId].quest = quest;
        poolInfo[marketId].creator = thisCreator;
        marketTypeGroup[marketType].push(marketId);
        marketPlace[marketId] = MarketPlace({
            marketType: marketType,
            place: getMarketGroupLength(marketType)
        });
        IEchoOptimisticOracle(oracle).injectQuest(marketId, quest);
        marketId++;
    }

    function getPoolInfo(uint256 thisMarketId) external view returns (PoolInfo memory thisPoolInfo) {
        thisPoolInfo = poolInfo[thisMarketId];
    }

    function getAaveInfo() external view returns (AaveInfo memory thisAaveInfo) {
        thisAaveInfo = aaveInfo;
    }

    function getTokenInfo(address token) external view returns (TokenInfo memory thisTokenInfo) {
        thisTokenInfo = tokenInfo[token];
    }

    function indexMarketTypeData(MarketType marketType, uint256 index) external view returns (uint256) {
        return marketTypeGroup[marketType][index];
    }

    function getMarketGroupLength(MarketType marketType) public view returns (uint256) {
        return marketTypeGroup[marketType].length;
    }

    function getMarketPlace(uint256 id) public view returns (MarketPlace memory) {
        return marketPlace[id];
    }

    function getFeeInfo(
        uint256 thisMarketId, 
        address elfHolder
    ) external view returns (FeeInfo memory thisFeeInfo) {
        thisFeeInfo = feeInfo[thisMarketId];
        uint256 elfAmount;
        if(elf != address(0)) {
            elfAmount = IERC721(elf).balanceOf(elfHolder);
        }
        if(elfAmount > 0) {
            thisFeeInfo = IAroundPoolFactory.FeeInfo({
                officialFee: thisFeeInfo.officialFee / 2,
                luckyFee: thisFeeInfo.luckyFee / 2,
                oracleFee: thisFeeInfo.oracleFee / 2,
                creatorFee: thisFeeInfo.creatorFee / 2,
                liquidityFee: thisFeeInfo.liquidityFee / 2,
                totalFee: thisFeeInfo.totalFee / 2
            });
        }
    }

}