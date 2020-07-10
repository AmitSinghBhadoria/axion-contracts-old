// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";
import "./@openzeppelin/contracts/math/SafeMath.sol";
import "./@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./DepositToken.sol";

contract SnapshotContract is AccessControl {
    using SafeMath for uint256;

    bytes32 private constant _MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private constant _ONE_DAY_TIMESTAMP = 86400;

    uint256 private _start;
    uint256 private _period;

    DepositToken private _claimToken;

    address private _transferTarget;
    address private _transferTargetSecond;

    constructor(
        address provider,
        uint256 period,
        address claimToken,
        address transferTarget
    ) public {
        _setupRole(_MINTER_ROLE, provider);
        _start = now;
        _period = period;
        _claimToken = DepositToken(claimToken);
        _transferTarget = transferTarget;
    }

    function getMinterRole() public pure returns (bytes32) {
        return _MINTER_ROLE;
    }

    function getOneDayTimestamp() public pure returns (uint256) {
        return _ONE_DAY_TIMESTAMP;
    }

    function getTransferTarget() public view returns (address) {
        return _transferTarget;
    }

    function getClaimToken() public view returns (IERC20) {
        return _claimToken;
    }

    function getPeriod() public view returns (uint256) {
        return _period;
    }

    function getStart() public view returns (uint256) {
        return _start;
    }

    function getMessageHash(uint256 amount, address account) public pure returns (bytes32) {
        return keccak256(abi.encode(amount, account));
    }

    function check(uint256 amount, bytes memory signature) public view returns (bool) {
        bytes32 messageHash =  getMessageHash(amount, address(msg.sender));
        return ECDSA.recover(messageHash, signature) == signerAddress;
    }

    function claim(uint256 amount, address account, bytes memory signature) external returns (bool) {
    	require(check(amount, signature), "CLAIM: cannot claim because signature is not correct");

        uint256 daysFromStart = now.sub(_start).div(_ONE_DAY_TIMESTAMP);
        uint256 delta = amount.mul(daysFromStart).div(_period);
        uint256 amountOut = amount.sub(delta);

        require(amount > 0);

        DepositToken(_claimToken).mint(_transferTarget, delta);
        DepositToken(_claimToken).mint(_msgSender(), amountOut);

        return true;
    }
}
