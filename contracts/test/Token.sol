// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor() public ERC20("TEST", "TST") {
        _mint(msg.sender, 100e18);
    }
}
