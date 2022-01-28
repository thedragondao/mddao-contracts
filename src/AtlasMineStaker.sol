// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import 'openzeppelin-contracts/token/ERC20/IERC20.sol';
import 'openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';
import 'openzeppelin-contracts/token/ERC1155/IERC1155.sol';
import 'openzeppelin-contracts/token/ERC721/IERC721.sol';
import 'openzeppelin-contracts/utils/Address.sol';
import 'openzeppelin-contracts/access/Ownable.sol';

import './interfaces/IAtlasMine.sol';
import {IERC20Mintable} from './drMAGIC.sol';

// TODO: Natspec
// TODO: Emergency functions
// TODO: Pull out interface
// TODO: Add migration for later altar
contract AtlasMineStaker is Ownable {
    using SafeERC20 for IERC20;
    using Address for address;

    // TODO: Do the rest of events
    event SetFee(uint256 fee);

    /// @notice MAGIC token
    address public constant magic = address(0x539bdE0d7Dbd336b79148AA742883198BBF60342);
    /// @notice Holder of Treasures and legions
    address private hoard;
    /// @notice The AtlasMine
    IAtlasMine public immutable mine;
    //// @notice The defined lock cycle for the contract
    AtlasMineLock public immutable lock;

    struct Stake {
        uint256 amount;
        uint256 unlockAt;
        uint256 depositId;
    }

    /// @notice The total amount of staked token
    uint256 public totalStaked;
    /// @notice The amount of tokens staked by an account
    mapping(address => uint256) public userStake;
    /// @notice All stakes currently active
    Stake[] public stakes;
    /// @notice Deposit ID of last stake. Also tracked in atlas mine
    uint256 lastDepositId;

    uint256 public fee;
    uint256 public feeReserve;
    uint256 public constant FEE_DENOMINATOR = 10000;
    /// @notice Max fee the owner can ever take - 10%
    uint256 public constant MAX_FEE = 1000;

    constructor(IAtlasMine _mine, AtlasMineLock _lock) {
        mine = _mine;

        /// @notice each staker cycles its locks for a predefined amount. New
        ///         lock cycle, new contract.
        lock = _lock;

        // Approve the mine
        IERC20(magic).safeApprove(address(mine), 2**256-1);
    }

    function deposit(uint256 _amount) public {
        require(_amount > 0, 'Deposit amount 0');

        // Update accounting
        userStake[msg.sender] += _amount;
        totalStaked += _amount;

        // Collect tokens
        IERC20(magic).safeTransferFrom(msg.sender, address(this), _amount);

        // MAGIC tokens sit in contract. Will be staked by owner.
    }

    function withdraw() public {
        // TODO: Figure out how 'withdraw windows' will work.

        // Update accounting
        uint256 amount = userStake[msg.sender];
        userStake[msg.sender] -= amount;
        totalStaked -= amount;

        // Distribute tokens
        _harvestMine();

        // TODO: Calculate pro rata magic and withdraw it from contract
        uint256 proRataMagic;

        require(
            proRataMagic <= _totalUsableMagic(),
            "Not enough unstaked"
        );
    }

    // Callable by owner.
    // Stake in atlas mine with a lock value.
    function stakeInMine(uint256 _amount) public onlyOwner {
        require(_amount <= _totalUsableMagic(), 'Not enough funds');

        uint256 depositId = ++lastDepositId;

        (,uint256 locktime) = mine.getLockBoost(lock);

        stakes.push(Stake({
            amount: _amount,
            unlockAt: block.timestamp + locktime,
            depositId: depositId
        }));

        mine.deposit(_amount, lock);
    }

    function unstakeFromMine(uint256 stakeIndex, uint256 _amount) external onlyOwner {
        // Get deposit ID from stake
        require(stakeIndex < stakes.length, 'Index out of bounds');

        Stake storage s = stakes[stakeIndex];
        require(s.unlockAt <= block.timestamp, 'Stake still locked');

        if (_amount > s.amount) {
            _amount = s.amount;
        }

        // Withdraw position - auto-harvest
        mine.withdrawAndHarvestPosition(s.depositId, _amount);

        _checkUpdateOrRemoveStake(stakeIndex);
    }

    function unstakeAllFromMine() external onlyOwner {
        // Unstake everything eligible

        uint256 i = 0;
        while (i < stakes.length) {
            Stake memory s = stakes[i];

            if (s.unlockAt > block.timestamp) {
                // This stake is not unlocked - stop looking
                break;
            }

            // Withdraw position - auto-harvest
            mine.withdrawAndHarvestPosition(s.depositId, s.amount);

            i++;
        }

        // Only check for removal after, so we don't mutate while looping
        // TODO: More efficient algo for this? Currently quadratic big-o
        for (uint256 j = 0; j < i; j++) {
            _checkUpdateOrRemoveStake(j);
        }
    }

    function compound() external onlyOwner {
        // Claim all rewards and restake them.
        // TODO; Is this necessary? Ties in with withdrawal window issue.

        _harvestMine();
        stakeInMine(_totalUsableMagic());
    }

    function stakeTreasure(uint256 _tokenId, uint256 _amount) external onlyHoard {
        // First withdraw and approve
        IERC1155 treasure = IERC1155(mine.treasure());

        treasure.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, bytes(''));
        treasure.setApprovalForAll(address(mine), true);

        mine.stakeTreasure(_tokenId, _amount);
    }

    function unstakeTreasure(uint256 _tokenId, uint256 _amount) external onlyHoard {
        // First withdraw and approve
        IERC1155 treasure = IERC1155(mine.treasure());

        mine.unstakeTreasure(_tokenId, _amount);
        treasure.safeTransferFrom(address(this), msg.sender, _tokenId, _amount, bytes(''));
    }

    function stakeLegion(uint256 _tokenId) external onlyHoard {
        // First withdraw and approve
        IERC721 legion = IERC721(mine.legion());

        legion.safeTransferFrom(msg.sender, address(this), _tokenId);
        legion.setApprovalForAll(address(mine), true);

        mine.stakeLegion(_tokenId);
    }

    function unstakeLegion(uint256 _tokenId) external onlyHoard {
        // First withdraw and approve
        IERC721 legion = IERC721(mine.legion());

        mine.unstakeLegion(_tokenId);
        legion.safeTransferFrom(address(this), msg.sender, _tokenId);
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= MAX_FEE, "Invalid fee");

        fee = _fee;

        emit SetFee(fee);
    }

    function setHoard(address _hoard) external onlyOwner {
        /// @notice Don't set to address 0! Already staked NFTs can only be
        ///         withdrawn to this address, even if they have been staked
        ///         by a different address.
        hoard = _hoard;
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = feeReserve;
        feeReserve = 0;

        IERC20(magic).safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Harvest rewards from the AtlasMine and send them back to
     *      this contract.
     *
     */
    function _harvestMine() internal returns (uint256, uint256) {
        uint256 preclaimBalance = IERC20(magic).balanceOf(address(this));
        mine.harvestAll();
        uint256 postclaimBalance = IERC20(magic).balanceOf(address(this));

        uint256 earned = postclaimBalance - preclaimBalance;

        // Reserve the 'fee' amount of what is earned
        uint256 feeEarned = earned * fee / FEE_DENOMINATOR;
        feeReserve += feeEarned;

        return (earned - feeEarned, feeEarned);
    }

    /**
     * @dev After mutating a stake (by withdrawing fully or partially),
     *      get updated data from the staking contract, and either update
     *      the stake amount or stop tracking it.
     */
    function _checkUpdateOrRemoveStake(uint256 stakeIndex) internal {
        Stake storage s = stakes[stakeIndex];

        AtlasMineUserInfo memory u = mine.userInfo(address(this), s.depositId);

        if (u.depositAmount == 0) {
            // remove stake from calculation
            _removeStake(stakeIndex);
        } else {
            s.amount = u.depositAmount;
        }
    }

    /**
     * @dev Calculate total amount of MAGIC usable by the contract.
     *      'Usable' means available for either withdrawal or re-staking.
     *      Counts unstaked magic less fee reserve.
     */
    function _totalUsableMagic() internal view returns (uint256) {
        // TODO: Another place that might need changing based on how
        // we set up withdrawal windows. Might want to differentiate
        // between what can be withdrawn vs. restaked.

        // Current magic held in contract
        uint256 unstaked = IERC20(magic).balanceOf(address(this));

        return unstaked - feeReserve;
    }

    /**
     * @dev Calculate total amount of MAGIC under control of the contract.
     *      Counts staked and unstaked MAGIC. Does _not_ count accumulated
     *      but unclaimed rewards.
     */
    function _totalControlledMagic() internal view returns (uint256) {
        // Current magic staked in mine
        uint256 staked = 0;

        for (uint256 i = 0; i < stakes.length; i++) {
            staked += stakes[i].amount;
        }

        return staked + _totalUsableMagic();
    }

    /**
     * @dev Remove a tracked stake from any position in the stakes array.
     */
    function _removeStake(uint256 index) internal {
        if (index >= stakes.length) return;

        for (uint i = index; i < stakes.length - 1; i++){
            stakes[i] = stakes[i + 1];
        }

        delete stakes[stakes.length - 1];

        stakes.pop();
    }

    modifier onlyHoard {
        require(msg.sender == hoard, 'Not hoard');

        _;
    }
}
