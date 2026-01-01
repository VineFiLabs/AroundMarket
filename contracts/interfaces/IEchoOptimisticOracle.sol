//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

interface IEchoOptimisticOracle {

    /*****************************Enum********************************** */
    enum OracleState{
        Normal,
        Dispute
    }

    enum EventState {
        Pending,
        Yes,
        No
    }

    enum OracleWithdrawState {
        Pending,
        providerWithdrawd,
        disputeWithdrawd
    }

    /*****************************Struct********************************** */
    struct DataProviderInfo {
        bool valid;
        uint64 latestSubmitTime;
        uint128 depositeAmount;
    }

    struct OracleInfo {
        EventState eventState;
        OracleWithdrawState withdrawState;
        uint16 yesVote;
        uint16 noVote;
        uint64 randomNumber;
        uint64 updateTime;
        uint256 earn;
        string quest;
        OptimisticInfo optimisticInfo;
    }

    struct OptimisticInfo {
        OracleState state;
        bool isDisputePass;
        uint16 disputeVotes;
        uint16 responseCount;
        address challenger; 
        string evidence;
        address[] providers;
        address[] investigators;
    }

    struct SubmitDataInfo {
        EventState eventState;
        bool isSubmit;
        uint256 randomNumber;
        string dataSources;
    }

    /*****************************Event********************************** */
    event SetWhitelist(address user, bool state);
    event RegisterProvider(address indexed newProvider);
    event ExitProvider(address indexed provider);
    event InjectFee(uint256 indexed thisMarketId, uint256 indexed value);
    event InjectQuest(uint256 indexed thisMarketId, string thisQuest);
    event SubmitData(address indexed provider, uint256 indexed thisMarketId, EventState thisEventState, uint64 thisRandomNumber);
    event Challenge(address indexed challenger, uint256 indexed thisMarketId);

    /*****************************Read********************************** */
    function threshold() external view returns (uint16);
    function disputePassThreshold() external view returns (uint16);
    function coolingTime() external view returns (uint32);
    function challengerFee() external view returns (uint256);
    function challengRewardRate() external view returns (uint256);
    function registFee() external view returns (uint256);

    function validCollateral(address) external view returns (bool);
    function investigator(address) external view returns (bool);
    function whitelist(address) external view returns (bool);

    function providerPledgeAmount(address) external view returns (uint256);


    function getOracleInfo(uint256 id) external view returns (
        OracleInfo memory thisOracleInfo
    );

    function getOnlyEventState(uint256 id) external view returns (EventState newEventState);

    function getSubmitDataInfo(address user, uint256 id) external view returns (SubmitDataInfo memory);

    /*****************************Write********************************** */
    //AroundMarket touch
    function injectQuest(uint256 id, string calldata thisQuest) external;
    function injectFee(uint256 id, uint256 value) external;

    //owner
    function initialize(address _aroundMarket, address _aroundPoolFactory) external;

    function setRegistFee(uint256 newRegistFee) external;

    function setChallengerFee(uint256 newChallengerFee) external;

    function setCoolingTime(uint32 newCoolingTime) external;

    function setWhitelist(address user, bool state) external;

    function setTroublemaker(address user, bool state) external;

    //User touch
    function registProvider() external;

    function exit() external;

    function disruptRandom(uint256 id, uint64 number) external;

    function submitData(
        uint256 id,
        bool isYes,
        uint64 randomNumber,
        string calldata eventDataSources
    ) external;

    function challenge(
        uint256 id, 
        string calldata evidence
    ) external;

    function disputeVote(
        uint256 id
    ) external;

    function withdrawEarn(
        uint256 id
    ) external;

    function withdrawDispute(
        uint256 id
    ) external;

}