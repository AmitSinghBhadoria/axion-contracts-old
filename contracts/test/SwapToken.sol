// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SwapToken is ERC20 {
    constructor() public ERC20("Swap Token", "SWP") {
        _mint(msg.sender, 1000000000e18);
    }
}
