// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "solady/src/auth/Ownable.sol";
import "@chainlink/contracts/src/v0.8/functions/FunctionsClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Treasury is Ownable, FunctionsClient {
    // =========================
    //   STATE VARIABLES
    // =========================
    IERC20 public immutable rewardToken;
    address public skillStaking;
    uint64 public subscriptionId;
    bytes32 public donJobId;
    uint32 public gasLimit = 300000;

    struct Claim {
        address user;
        uint256 playerId;
        uint256 amount;
    }
    mapping(bytes32 => Claim) public pendingClaims;

    // =========================
    //   EVENTS
    // =========================
    event Deposited(address indexed from, uint256 amount);
    event SkillStakingSet(address indexed skillStaking);
    event ClaimRequested(bytes32 indexed requestId, address indexed user, uint256 playerId, uint256 amount);
    event YieldPaid(address indexed user, uint256 playerId, uint256 amount);

    // =========================
    //   MODIFIERS
    // =========================
    modifier onlySkillStaking() {
        require(msg.sender == skillStaking, "Not SkillStaking");
        _;
    }

    // =========================
    //   CONSTRUCTOR
    // =========================
    constructor(
        address _functionsRouter,
        address _rewardToken,
        uint64 _subscriptionId,
        bytes32 _donJobId
    ) FunctionsClient(_functionsRouter) Ownable() {
        rewardToken = IERC20(_rewardToken);
        subscriptionId = _subscriptionId;
        donJobId = _donJobId;
    }

    // =========================
    //   ADMIN FUNCTIONS
    // =========================
    function setSkillStaking(address _skillStaking) external onlyOwner {
        skillStaking = _skillStaking;
        emit SkillStakingSet(_skillStaking);
    }

    function setGasLimit(uint32 _gasLimit) external onlyOwner {
        gasLimit = _gasLimit;
    }

    // =========================
    //   DEPOSIT FUNCTION
    // =========================
    /// @notice Deposit ERC20 tokens to fund yield rewards
    function deposit(uint256 amount) external {
        require(amount > 0, "Zero deposit");
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit Deposited(msg.sender, amount);
    }

    // =========================
    //   CLAIM LOGIC (CALLED BY SKILLSTAKING)
    // =========================
    /// @notice Called by SkillStaking to initiate a yield claim via Chainlink Functions
    function claimYield(
        address user,
        uint256 playerId,
        uint256 amount,
        bytes calldata functionsRequest
    ) external onlySkillStaking returns (bytes32 requestId) {
        requestId = _sendRequest(
            functionsRequest,
            subscriptionId,
            gasLimit,
            donJobId
        );
        pendingClaims[requestId] = Claim(user, playerId, amount);
        emit ClaimRequested(requestId, user, playerId, amount);
    }

    // =========================
    //   CHAINLINK FUNCTIONS CALLBACK
    // =========================
    /// @notice Chainlink Functions callback: pays out yield and updates SkillStaking
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory /* err */
    ) internal override {
        Claim memory claim = pendingClaims[requestId];
        require(claim.user != address(0), "Invalid claim");

        // Decode the response (e.g., amount approved for payout)
        uint256 payoutAmount = abi.decode(response, (uint256));
        require(payoutAmount > 0, "No yield");

        // Pay out the yield
        require(rewardToken.transfer(claim.user, payoutAmount), "Payout failed");

        // Update the user's position in SkillStaking (e.g., set lastClaimBlock, etc.)
        ISkillStaking(skillStaking).onYieldClaimed(claim.user, claim.playerId, payoutAmount);

        emit YieldPaid(claim.user, claim.playerId, payoutAmount);

        // Clean up
        delete pendingClaims[requestId];
    }
}

// Minimal interface for SkillStaking callback
interface ISkillStaking {
    function onYieldClaimed(address user, uint256 playerId, uint256 amount) external;
}
