// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/access/Ownable.sol";
import "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking is Ownable {
    using SafeERC20 for IERC20;

    event Stake(
        address indexed account,
        uint256 startDate,
        uint256 endDate,
        uint256 indexed stakingId,
        uint256 indexed shares,
        uint256 stakedAmount
    );

    event Unstake(
        address indexed account,
        uint256 unstakeDate,
        uint256 indexed stakingId,
        uint256 indexed shares
    );

    uint256 private currentStakingId;

    // stakingId => UserStaking
    mapping(uint256 => UserStaking) private userStakingOf;

    IERC20 private token;

    uint256 private pool;

    uint private baseApy;
    uint[6] private bonusApy;

    struct UserStaking {
        address account;
        uint256 stakingId;
        uint256 startDate;
        uint256 endDate;
        uint256 unstakeDate;
        uint256 stakedAmount;
        uint256 shares;
    }

    constructor(address _token, uint _baseApy, uint[] memory _bonusApy) public {
        token = IERC20(_token);
        baseApy = _baseApy;
        initBonusApy(_bonusApy);
    }

    function initBonusApy(uint[] memory _bonusApy) private {
        for (uint i = 0; i < _bonusApy.length; i++) {
            bonusApy[i] = _bonusApy[i];
        }
    }

    function addToPool(uint256 amount) public {
        token.safeTransferFrom(msg.sender, address(this), amount);
        pool += amount;
    }

    function stake(uint256 amount, uint periodDays) public {
        require(amount > 0, 'token amount must be > 0');
        require(periodDays > 0, 'staking period in days must be > 0');

        token.safeTransferFrom(msg.sender, address(this), amount);

        uint256 reward = calculateReward(periodDays);
        uint256 shares = amount + reward;

        if (shares > pool) {
            revert("Not enough tokens in pool");
        }

        uint256 stakingId = currentStakingId;
        uint256 startDate = block.timestamp;
        uint256 endDate = startDate + periodDays;

        userStakingOf[currentStakingId] = UserStaking({
            account: msg.sender,
            stakingId: stakingId,
            startDate: startDate,
            endDate: startDate + periodDays,
            unstakeDate: 0,
            stakedAmount: amount,
            shares: shares
        });

        currentStakingId = currentStakingId + 1;

        // [event]
        emit Stake(
            msg.sender,
            startDate,
            endDate,
            stakingId,
            shares,
            amount
        );
    }

    function unstake(uint256 stakingId) public {
        UserStaking storage userStaking = userStakingOf[stakingId];
        address userAccount = msg.sender;

        require(
            userStaking.account == userAccount,
            'userStaking.account != userAccount'
        );
        require(
            userStaking.unstakeDate == 0,
            'stake has already been unstaked'
        );


        uint256 endDate = userStaking.endDate;
        require(
            block.timestamp > endDate,
            'the stake is not ended yet'
        );

        uint256 unstakeDate = block.timestamp;
        userStaking.unstakeDate = unstakeDate;

        token.safeTransfer(userAccount, userStaking.shares);

        // [event]
        emit Unstake(
            userAccount,
            unstakeDate,
            userStaking.stakingId,
            userStaking.shares
        );
    }

    function calculateReward(uint periodDays) private returns(uint256) {
        uint _bonusApy = calculateBonusApy(periodDays);
        return periodDays * (baseApy + _bonusApy) / 365;
    }

    function calculateBonusApy(uint periodDays) private returns(uint) {
        if (periodDays < 7) {
            return 0;
        } else if (periodDays < 14) {
            return bonusApy[0];
        } else if (periodDays < 30) {
            return bonusApy[1];
        } else if (periodDays < 60) {
            return bonusApy[2];
        } else if (periodDays < 180) {
            return bonusApy[3];
        } else if (periodDays < 300) {
            return bonusApy[4];
        } else {
            return bonusApy[5];
        }
    }

    function withdrawTokens() public onlyOwner {
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }
}
