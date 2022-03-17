// SPDX-License-Identifier: MIT

pragma solidity 0.8.3;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/INFT.sol";

/// @title Staking Contract
/// @notice You can use this contract for staking tokens and distribute rewards
/// @dev All function calls are currently implemented without side effects
contract Staking is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;
    using SafeCastUpgradeable for int256;
    using SafeCastUpgradeable for uint256;

    /// @notice Info of each user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of reward entitled to user.
    /// `lastDepositedAt` The timestamp of the last deposit.
    /// `accRewardPerShare` reward amount allocated per LP token.
    /// `lastRewardTime` Last time that the reward is calculated.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
        uint256 lastDepositedAt;
        uint256 accRewardPerShare;
        uint256 lastRewardTime;
    }

    uint256 public constant APY_ACCURACY = 1e4;

    uint256 private constant ACC_REWARD_PRECISION = 1e12;

    /// @notice Address of reward contract.
    IERC20Upgradeable public rewardToken;

    /// @notice Address of the LP token.
    IERC20Upgradeable public lpToken;

    /// @notice Reward treasury
    address public rewardTreasury;

    /// @notice Fee collector
    address public feeCollector;

    /// @notice Fee rate
    uint256 public feeRate;

    /// @notice APY
    uint256 public baseAPY;

    /// @notice Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    /// @notice woker(nft contract or someone to set custom things)
    address public worker;

    /// @notice Lock info for each user.
    mapping(address => uint256) public lockExpiresAt;

    /// @notice NFT address
    address public nft;

    event Deposit(address indexed user, uint256 amount, address indexed to);
    event Withdraw(address indexed user, uint256 amount, address indexed to);
    event Claim(address indexed user, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 amount,
        address indexed to
    );

    event LogUpdate(
        address indexed user,
        uint256 lastRewardTime,
        uint256 amount,
        uint256 accRewardPerShare
    );
    event LogRewardTreasury(address indexed wallet);

    modifier onlyOwnerOrWorker {
        require(_msgSender() == worker || _msgSender() == owner(), "Not owner or worker");
        _;
    }

    /**
     * @param _rewardToken The reward token contract address.
     * @param _lpToken The staking contract address.
     * @param _rewardTreasury The reward treasury contract address.
     * @param _baseAPY The APY of reward to be distributed per second.
     */
    function initialize(
        IERC20Upgradeable _rewardToken, 
        IERC20Upgradeable _lpToken, 
        address _rewardTreasury, 
        address _feeCollector, 
        uint256 _baseAPY
    ) public initializer {
        __ReentrancyGuard_init_unchained();
        __Ownable_init_unchained();
        __Pausable_init();

        rewardToken = _rewardToken;
        lpToken = _lpToken;
        rewardTreasury = _rewardTreasury;
        feeCollector = _feeCollector;
        baseAPY = _baseAPY;

        feeRate = 1;
    }

    /**
     * @notice Sets the reward per second to be distributed. Can only be called by the owner.
     * @dev Its decimals count is ACC_REWARD_PRECISION
     * @param _baseAPY The amount of reward to be distributed per second.
     */
    function setBaseAPY(uint256 _baseAPY) public onlyOwner {
        baseAPY = _baseAPY;
    }

    /**
     * @notice set reward wallet
     * @param _wallet address that contains the rewards
     */
    function setRewardTreasury(address _wallet) external onlyOwner {
        rewardTreasury = _wallet;
        emit LogRewardTreasury(_wallet);
    }

    /**
     * @notice set fee collector
     * @param _feeCollector address that contains the rewards
     */
    function setFeeCollector(address _feeCollector) external onlyOwner {
        feeCollector = _feeCollector;
    }

    /**
     * @notice set rate
     * @param _feeRate address that contains the rewards
     */
    function setFeeRate(uint256 _feeRate) external onlyOwner {
        feeRate = _feeRate;
    }

    /**
     * @notice set worker
     * @param _worker address of worker
     */
    function setWorker(address _worker) external onlyOwner {
        worker = _worker;
    }

    /**
     * @notice set nft
     * @param _nft address of nft
     */
    function setNFT(address _nft) external onlyOwner {
        nft = _nft;
    }

    /**
     * @notice return available reward amount
     * @return rewardInTreasury reward amount in treasury
     * @return rewardAllowedForThisPool allowed reward amount to be spent by this pool
     */
    function availableReward()
        public
        view
        returns (uint256 rewardInTreasury, uint256 rewardAllowedForThisPool)
    {
        rewardInTreasury = rewardToken.balanceOf(rewardTreasury);
        rewardAllowedForThisPool = rewardToken.allowance(
            rewardTreasury,
            address(this)
        );
    }

    /**
     * @notice Caclulates the reward apy of the user
     * @return APY
     */
    function rewardAPY(address _user) public view returns (uint256) {
        uint256 tierFactor = _tierFactor(_user);
        uint256 bonusRate = 0;
        if (nft != address(0)) {
            (uint256 multiplier, uint256 precision) = INFT(nft).getStakingRateMultiplier(_user);
            bonusRate = baseAPY.mul(multiplier).div(precision);
        }
        return baseAPY.mul(tierFactor).div(100).add(bonusRate);
    }

    /**
     * @notice Caclulates the tier factor of the user that affects 
     * @return Tier factor of the user - accuracy: 10
     */
    function _tierFactor(address _user) internal view returns (uint256) {
        // PCR decimals: 18
        UserInfo memory user = userInfo[_user];
        if (user.amount < 5000 * 10**18) return 100;
        if (user.amount < 15000 * 10**18) return 125;
        if (user.amount < 35000 * 10**18) return 150;
        if (user.amount < 100000 * 10**18) return 175;
        return 200; 
    }

    /**
     * @notice View function to see pending reward on frontend.
     * @dev It doens't update accRewardPerShare, it's just a view function.
     * @param _user Address of user.
     * @return pending reward for a given user.
     */
    function pendingReward(address _user)
        external
        view
        returns (uint256 pending)
    {
        UserInfo memory user = userInfo[_user];
        uint256 accRewardPerShare_ = user.accRewardPerShare;
        uint256 apy = rewardAPY(_user);

        if (block.timestamp > user.lastRewardTime && user.amount != 0) {
            uint256 time = block.timestamp.sub(user.lastRewardTime);
            uint256 timeReward = user.amount.mul(time).mul(ACC_REWARD_PRECISION).mul(apy).div(APY_ACCURACY).div(365 days);
            accRewardPerShare_ = accRewardPerShare_.add(timeReward / user.amount);
        }
        pending = ((user.amount.mul(accRewardPerShare_).div(ACC_REWARD_PRECISION)).toInt256().sub(user.rewardDebt)).toUint256();
    }

    /**
     * @notice Update reward variables.
     * @dev Updates accRewardPerShare and lastRewardTime.
     */
    function setLock(address _user, uint256 expiresAt) external onlyOwnerOrWorker {
        lockExpiresAt[_user] = expiresAt;
    }

    /**
     * @notice Update reward variables.
     * @dev Updates accRewardPerShare and lastRewardTime.
     */
    function update(address _user) public {
        UserInfo storage user = userInfo[_user];
        uint256 apy = rewardAPY(_user);
        if (block.timestamp > user.lastRewardTime) {
            if (user.amount > 0) {
                uint256 time = block.timestamp.sub(user.lastRewardTime);
                uint256 timeReward = user.amount.mul(time).mul(ACC_REWARD_PRECISION).mul(apy).div(APY_ACCURACY).div(365 days);
                user.accRewardPerShare = user.accRewardPerShare.add(timeReward.div(user.amount));
            }
            user.lastRewardTime = block.timestamp;
            emit LogUpdate(_user, user.lastRewardTime, user.amount, user.accRewardPerShare);
        }
    }

    /**
     * @notice Deposit LP tokens for reward allocation.
     * @param amount LP token amount to deposit.
     * @param to The receiver of `amount` deposit benefit.
     */
    function deposit(uint256 amount, address to) public nonReentrant whenNotPaused {
        update(to);
        UserInfo storage user = userInfo[to];

        uint256 feeAmount = amount * feeRate / APY_ACCURACY;
        lpToken.safeTransferFrom(msg.sender, feeCollector, feeAmount);
        amount = amount - feeAmount;

        // Effects
        user.lastDepositedAt = block.timestamp;
        user.amount = user.amount.add(amount);
        user.rewardDebt = user.rewardDebt.add(
            int256(amount.mul(user.accRewardPerShare) / ACC_REWARD_PRECISION)
        );

        lpToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, amount, to);
    }

    /**
     * @notice Withdraw LP tokens and harvest rewards to `to`.
     * @param amount LP token amount to withdraw.
     * @param to Receiver of the LP tokens and rewards.
     */
    function withdraw(uint256 amount, address to) public nonReentrant whenNotPaused {
        require(lockExpiresAt[msg.sender] < block.timestamp, "Lock not expired");

        update(to);
        UserInfo storage user = userInfo[msg.sender];

        int256 accumulatedReward = int256(
            user.amount.mul(user.accRewardPerShare) / ACC_REWARD_PRECISION
        );
        uint256 _pendingReward = accumulatedReward
            .sub(user.rewardDebt)
            .toUint256();

        // Effects
        user.rewardDebt = accumulatedReward.sub(
            int256(amount.mul(user.accRewardPerShare) / ACC_REWARD_PRECISION)
        );
        user.amount = user.amount.sub(amount);

        rewardToken.safeTransferFrom(rewardTreasury, to, _pendingReward);

        uint256 lpFee = amount * feeRate / APY_ACCURACY;
        lpToken.safeTransfer(feeCollector, lpFee);
        lpToken.safeTransfer(to, amount - lpFee);

        emit Withdraw(msg.sender, amount, to);
        emit Claim(msg.sender, _pendingReward);
    }

    /**
     * @notice Claim rewards and send to `to`.
     * @dev Here comes the formula to calculate reward token amount
     * @param to Receiver of rewards.
     */
    function claim(address to) public nonReentrant whenNotPaused {
        update(to);
        UserInfo storage user = userInfo[msg.sender];
        int256 accumulatedReward = int256(
            user.amount.mul(user.accRewardPerShare) / ACC_REWARD_PRECISION
        );
        uint256 _pendingReward = accumulatedReward
            .sub(user.rewardDebt)
            .toUint256();

        // Effects
        user.rewardDebt = accumulatedReward;

        // Interactions
        if (_pendingReward != 0) {
            rewardToken.safeTransferFrom(rewardTreasury, to, _pendingReward);
        }

        emit Claim(msg.sender, _pendingReward);
    }

    /**
     * @notice Withdraw without caring about rewards. EMERGENCY ONLY.
     * @param to Receiver of the LP tokens.
     */
    function emergencyWithdraw(address to) public nonReentrant whenNotPaused {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        uint256 lpFee = amount * feeRate / APY_ACCURACY;
        lpToken.safeTransfer(feeCollector, lpFee);

        // Note: transfer can fail or succeed if `amount` is zero.
        lpToken.safeTransfer(to, amount - lpFee);

        emit EmergencyWithdraw(msg.sender, amount, to);
    }

    function renounceOwnership() public override onlyOwner {
        revert();
    }
}
