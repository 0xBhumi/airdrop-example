// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {SignatureChecker} from "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";
import {SuperchainERC20} from "@contracts-bedrock/src/L2/SuperchainERC20.sol";
import {Distributor} from "./Distributor.sol";
import {console} from "forge-std/console.sol";

struct CampaignParameters {
    bytes32 campaignId;
    address creator;
    address rewardToken;
    uint256 amount;
    uint32 campaignType;
    uint32 startTimestamp;
    // Duration of the campaign in seconds. Has to be a multiple of EPOCH = 3600
    uint32 duration;
    bytes campaignData;
}

contract CampaignCreator is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                 CONSTANTS / VARIABLES                                              
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    uint32 public constant HOUR = 3600;

    uint256 public immutable CHAIN_ID = block.chainid;

    /// @notice Contract distributing rewards to users
    address public distributor;

    /// @notice Owner of the contract
    address public owner;

    /// @notice List of all rewards ever distributed or to be distributed in the contract
    /// @dev An attacker could try to populate this list. It shouldn't be an issue as only view functions
    /// iterate on it
    CampaignParameters[] public campaignList;

    /// @notice Maps a campaignId to the ID of the campaign in the campaign list + 1
    mapping(bytes32 => uint256) internal _campaignLookup;

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                        EVENTS                                                      
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    event DistributorUpdated(address indexed _distributor);
    event NewCampaign(CampaignParameters campaign);

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                        ERRORS                                                      
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error CampaignDoesNotExist();
    error InvalidParam();
    error CampaignDurationBelowHour();
    error CampaignAlreadyExists();

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                       MODIFIERS                                                    
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the `msg.sender` is the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                      CONSTRUCTOR                                                   
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    constructor(address _owner, address _distributor) {
        if (_distributor == address(0) || _owner == address(0))
            revert ZeroAddress();
        distributor = _distributor;
        owner = _owner;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                 USER FACING FUNCTIONS                                              
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Creates a `campaign` to incentivize a given pool for a specific period of time
    /// @return The campaignId of the new campaign
    /// @dev If the campaign is badly specified, it will not be handled by the campaign script and rewards may be lost
    /// @dev Reward tokens sent as part of campaigns must have been whitelisted before and amounts
    /// sent should be bigger than a minimum amount specific to each token
    /// @dev This function reverts if the sender has not accepted the terms and conditions
    function createCampaign(
        CampaignParameters memory newCampaign
    ) external nonReentrant returns (bytes32) {
        return _createCampaign(newCampaign);
    }

    /// @notice Same as the function above but for multiple campaigns at once
    /// @return List of all the campaign amounts actually deposited for each `campaign` in the `campaigns` list
    function createCampaigns(
        CampaignParameters[] memory campaigns
    ) external nonReentrant returns (bytes32[] memory) {
        uint256 campaignsLength = campaigns.length;
        bytes32[] memory campaignIds = new bytes32[](campaignsLength);
        for (uint256 i; i < campaignsLength; ) {
            campaignIds[i] = _createCampaign(campaigns[i]);
            unchecked {
                ++i;
            }
        }
        return campaignIds;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                        GETTERS                                                     
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the index of a campaign in the campaign list
    function campaignLookup(bytes32 _campaignId) public view returns (uint256) {
        uint256 index = _campaignLookup[_campaignId];
        if (index == 0) revert CampaignDoesNotExist();
        return index - 1;
    }

    /// @notice Returns the campaign parameters of a given campaignId
    /// @dev If a campaign has been overriden, this function still shows the original state of the campaign
    function campaign(
        bytes32 _campaignId
    ) public view returns (CampaignParameters memory) {
        return campaignList[campaignLookup(_campaignId)];
    }

    /// @notice Returns the campaign ID for a given campaign
    /// @dev The campaign ID is computed as the hash of the following parameters:
    ///  - `campaign.chainId`
    ///  - `campaign.creator`
    ///  - `campaign.rewardToken`
    ///  - `campaign.campaignType`
    ///  - `campaign.startTimestamp`
    ///  - `campaign.duration`
    ///  - `campaign.campaignData`
    /// This prevents the creation by the same account of two campaigns with the same parameters
    /// which is not a huge issue
    function campaignId(
        CampaignParameters memory campaignData
    ) public view returns (bytes32) {
        return
            bytes32(
                keccak256(
                    abi.encodePacked(
                        CHAIN_ID,
                        campaignData.creator,
                        campaignData.rewardToken,
                        campaignData.campaignType,
                        campaignData.startTimestamp,
                        campaignData.duration,
                        campaignData.campaignData
                    )
                )
            );
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                 GOVERNANCE FUNCTIONS                                               
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Sets a new `distributor` to which rewards should be distributed
    function setNewDistributor(address _distributor) external onlyOwner {
        if (_distributor == address(0)) revert InvalidParam();
        distributor = _distributor;
        emit DistributorUpdated(_distributor);
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                       INTERNAL                                                     
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Internal version of `createCampaign`
    function _createCampaign(
        CampaignParameters memory newCampaign
    ) internal returns (bytes32) {
        // if the campaign doesn't last at least one hour
        if (newCampaign.duration < HOUR) revert CampaignDurationBelowHour();

        if (newCampaign.creator == address(0)) newCampaign.creator = msg.sender;

        SuperchainERC20(newCampaign.rewardToken).transferFrom(
            msg.sender,
            distributor,
            newCampaign.amount
        );
        console.log(
            "check....",
            SuperchainERC20(newCampaign.rewardToken).balanceOf(distributor)
        );
        newCampaign.campaignId = campaignId(newCampaign);

        if (_campaignLookup[newCampaign.campaignId] != 0)
            revert CampaignAlreadyExists();
        _campaignLookup[newCampaign.campaignId] = campaignList.length + 1;
        campaignList.push(newCampaign);
        emit NewCampaign(newCampaign);

        return newCampaign.campaignId;
    }
}
