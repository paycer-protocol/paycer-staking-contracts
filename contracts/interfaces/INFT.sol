// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.3;

interface INFT {
    function getStakingRateMultiplier(address user) external view returns (uint256 multiplier, uint256 precision);
}
