// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CrowdFundHub {
    
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool goalAchieved;
    }
    
    struct Contribution {
        address contributor;
        uint256 amount;
        uint256 timestamp;
    }
    
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => Contribution[]) public campaignContributions;
    mapping(uint256 => mapping(address => uint256)) public contributorAmounts;
    
    uint256 public campaignCounter;
    uint256 public platformFee = 25; // 2.5% platform fee (in basis points)
    address payable public platformOwner;
    
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    
    event RefundClaimed(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    modifier onlyActiveCampaign(uint256 _campaignId) {
        require(campaigns[_campaignId].isActive, "Campaign is not active");
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign has ended");
        _;
    }
    
    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].creator, "Only campaign creator can call this");
        _;
    }
    
    constructor() {
        platformOwner = payable(msg.sender);
        campaignCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new crowdfunding campaign
     * @param _title Campaign title
     * @param _description Campaign description
     * @param _goalAmount Target amount to raise (in wei)
     * @param _durationInDays Campaign duration in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) public returns (uint256) {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        campaigns[campaignCounter] = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            isActive: true,
            goalAchieved: false
        });
        
        emit CampaignCreated(
            campaignCounter,
            msg.sender,
            _title,
            _goalAmount,
            deadline
        );
        
        return campaignCounter++;
    }
    
    /**
     * @dev Core Function 2: Contribute to a campaign
     * @param _campaignId ID of the campaign to contribute to
     */
    function contributeToCamera(uint256 _campaignId) 
        public 
        payable 
        onlyActiveCampaign(_campaignId) 
    {
        require(msg.value > 0, "Contribution must be greater than 0");
        require(
            msg.sender != campaigns[_campaignId].creator, 
            "Campaign creator cannot contribute to their own campaign"
        );
        
        Campaign storage campaign = campaigns[_campaignId];
        
        campaign.raisedAmount += msg.value;
        contributorAmounts[_campaignId][msg.sender] += msg.value;
        
        campaignContributions[_campaignId].push(Contribution({
            contributor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));
        
        // Check if goal is achieved
        if (campaign.raisedAmount >= campaign.goalAmount && !campaign.goalAchieved) {
            campaign.goalAchieved = true;
        }
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Withdraw funds or claim refunds based on campaign outcome
     * @param _campaignId ID of the campaign
     */
    function processPayment(uint256 _campaignId) public {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        require(campaign.isActive, "Campaign has already been processed");
        
        if (campaign.goalAchieved || campaign.raisedAmount >= campaign.goalAmount) {
            // Goal achieved - allow creator to withdraw funds
            require(
                msg.sender == campaign.creator, 
                "Only campaign creator can withdraw successful campaign funds"
            );
            
            uint256 platformFeeAmount = (campaign.raisedAmount * platformFee) / 1000;
            uint256 creatorAmount = campaign.raisedAmount - platformFeeAmount;
            
            campaign.isActive = false;
            
            // Transfer platform fee
            if (platformFeeAmount > 0) {
                platformOwner.transfer(platformFeeAmount);
            }
            
            // Transfer remaining amount to creator
            campaign.creator.transfer(creatorAmount);
            
            emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
            
        } else {
            // Goal not achieved - allow contributors to claim refunds
            uint256 contributedAmount = contributorAmounts[_campaignId][msg.sender];
            require(contributedAmount > 0, "No contributions found for this address");
            
            contributorAmounts[_campaignId][msg.sender] = 0;
            payable(msg.sender).transfer(contributedAmount);
            
            emit RefundClaimed(_campaignId, msg.sender, contributedAmount);
        }
    }
    
    // View functions
    function getCampaignDetails(uint256 _campaignId) 
        public 
        view 
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            bool goalAchieved
        ) 
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.goalAchieved
        );
    }
    
    function getContributionCount(uint256 _campaignId) public view returns (uint256) {
        return campaignContributions[_campaignId].length;
    }
    
    function getContributorAmount(uint256 _campaignId, address _contributor) 
        public 
        view 
        returns (uint256) 
    {
        return contributorAmounts[_campaignId][_contributor];
    }
    
    function getTotalCampaigns() public view returns (uint256) {
        return campaignCounter;
    }
    
    // Admin functions
    function updatePlatformFee(uint256 _newFee) public {
        require(msg.sender == platformOwner, "Only platform owner can update fee");
        require(_newFee <= 100, "Platform fee cannot exceed 10%");
        platformFee = _newFee;
    }
    
    function transferOwnership(address payable _newOwner) public {
        require(msg.sender == platformOwner, "Only current owner can transfer ownership");
        require(_newOwner != address(0), "New owner cannot be zero address");
        platformOwner = _newOwner;
    }
}
