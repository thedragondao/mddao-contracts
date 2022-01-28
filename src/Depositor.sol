// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import 'openzeppelin-contracts/token/ERC20/IERC20.sol';
import 'openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';
import 'openzeppelin-contracts/utils/Address.sol';
import 'openzeppelin-contracts/access/Ownable.sol';

import './interfaces/IAtlasMine.sol';
import {IERC20Mintable} from './dragonMAGIC.sol';

contract Depositor is Ownable {
    using SafeERC20 for IERC20;
    using Address for address;

    address public constant magic = address(0x539bdE0d7Dbd336b79148AA742883198BBF60342);

    // TODO: replace with real interface
    address public immutable staker;
    IERC20Mintable public immutable depositToken;
    IAtlasMine public immutable mine;

    constructor(address _staker, IERC20Mintable _depositToken, IAtlasMine _mine) {
        staker = _staker;
        depositToken = _depositToken;
        mine = _mine;
    }

    function deposit(uint256 _amount) public {
        require(_amount > 0, 'Deposit amount 0');

        // Collect tokens
        IERC20(magic).safeTransferFrom(msg.sender, address(this), _amount);

        // TODO:
        // Send these tokens to the staking proxy

        // Mint dragonMAGIC
        IERC20Mintable(depositToken).mint(msg.sender, _amount);
    }

    // Callable by owner.
    // Stake in atlas mine with a lock value.
    // Need stakingproxy
    // Need to manage a withdrawal queue.
    // function stakeInAtlasMine()
}
