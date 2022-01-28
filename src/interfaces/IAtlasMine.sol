// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

enum AtlasMineLock { twoWeeks, oneMonth, threeMonths, sixMonths, twelveMonths }

struct AtlasMineUserInfo {
    uint256 originalDepositAmount;
    uint256 depositAmount;
    uint256 lpAmount;
    uint256 lockedUntil;
    uint256 vestingLastUpdate;
    int256 rewardDebt;
    AtlasMineLock lock;
}

interface IAtlasMine {
    // Getters
    function userInfo(address _user, uint256 _depositId) external view returns (AtlasMineUserInfo memory);
    function treasure() external view returns (address);
    function legion() external view returns (address);

    // Methods
    function getStakedLegions(address _user) external view returns (uint256[] memory);
    function getUserBoost(address _user) external view returns (uint256);
    function getLegionBoostMatrix() external view returns (uint256[][] memory);
    function getLegionBoost(uint256 _legionGeneration, uint256 _legionRarity) external view returns (uint256);
    function utilization() external view returns (uint256 util);
    function getRealMagicReward(uint256 _magicReward) external view
        returns (uint256 distributedRewards, uint256 undistributedRewards);
    function getAllUserDepositIds(address _user) external view returns (uint256[] memory);
    function getExcludedAddresses() external view returns (address[] memory);
    function getLockBoost(AtlasMineLock _lock) external pure returns (uint256 boost, uint256 timelock);
    function getVestingTime(AtlasMineLock _lock) external pure returns (uint256 vestingTime);
    function calcualteVestedPrincipal(address _user, uint256 _depositId) external view returns (uint256 amount);
    function pendingRewardsPosition(address _user, uint256 _depositId) external view returns (uint256 pending);
    function pendingRewardsAll(address _user) external view returns (uint256 pending);
    function deposit(uint256 _amount, AtlasMineLock _lock) external;
    function withdrawPosition(uint256 _depositId, uint256 _amount) external returns (bool);
    function withdrawAll() external;
    function harvestPosition(uint256 _depositId) external;
    function harvestAll() external;
    function withdrawAndHarvestPosition(uint256 _depositId, uint256 _amount) external;
    function withdrawAndHarvestAll() external;
    function stakeTreasure(uint256 _tokenId, uint256 _amount) external;
    function unstakeTreasure(uint256 _tokenId, uint256 _amount) external;
    function stakeLegion(uint256 _tokenId) external;
    function unstakeLegion(uint256 _tokenId) external;
    function isLegion1_1(uint256 _tokenId) external view returns (bool);
    function getNftBoost(address _nft, uint256 _tokenId, uint256 _amount) external view returns (uint256);
    function getTreasureBoost(uint256 _tokenId, uint256 _amount) external pure returns (uint256 boost);
}