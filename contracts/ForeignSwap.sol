// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";
import "./@openzeppelin/contracts/math/SafeMath.sol";
import "./@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./interfaces/IToken.sol";
import "./interfaces/IAuction.sol";

contract NativeSwap is AccessControl {
    using SafeMath for uint256;

    bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");

    uint256 public start;
    uint256 public stepTimestamp;
    uint256 public maxClaimAmount;
    uint256 public constant PERIOD = 350;

    address public mainToken;
    address public auctionDaily;
    address public auctionWeekly;
    address public bigPayDayPool;
    address public signerAddress;

    mapping(address => uint256) public swapTokenBalanceOf;

    modifier onlySetter() {
        require(hasRole(SETTER_ROLE, _msgSender()), "Caller is not a setter");
        _;
    }

    constructor(
        uint256 _stepTimestamp,
        uint256 _maxClaimAmount,
        address _mainToken,
        address _setter
    ) public {
        _setupRole(SETTER_ROLE, _setter);
        signerAddress = _setter;
        start = now;
        stepTimestamp = _stepTimestamp;
        maxClaimAmount = _maxClaimAmount;
        mainToken = _mainToken;
    }

    function init(address _dailyAuction, address _weeklyAuction, address _bigPayDayPool) external onlySetter {
        auctionDaily = _dailyAuction;
        auctionWeekly = _weeklyAuction;
        bigPayDayPool = _bigPayDayPool;
        renounceRole(SETTER_ROLE, _msgSender());
    }

    function calculateStepsFromStart() internal view returns (uint256) {
        return (now.sub(start)).div(stepTimestamp);
    }

    function getMessageHash(uint256 amount, address account) public pure returns (bytes32) {
        return keccak256(abi.encode(amount, account));
    }

    function check(uint256 amount, bytes memory signature) public view returns (bool) {
        bytes32 messageHash =  getMessageHash(amount, address(msg.sender));
        return ECDSA.recover(messageHash, signature) == signerAddress;
    }

    function claimFromForeign(uint256 amount, bytes memory signature) public returns (bool) {
        require(amount > 0, "amount <= 0");
    	require(check(amount, signature), "CLAIM: cannot claim because signature is not correct");

    	uint256 deltaAuctionWeekly = 0;
    	if (amount > maxClaimAmount) {
    		deltaAuctionWeekly = amount.sub(maxClaimAmount);
    		amount = maxClaimAmount;
    	}

        uint256 stepsFromStart = calculateStepsFromStart();
        uint256 delta = amount.mul(stepsFromStart).div(PERIOD);
        uint256 amountOut = amount.sub(delta);
        uint256 deltaPart = delta.div(350);
        uint256 deltaAuctionDaily = deltaPart.mul(349);


        IToken(mainToken).mint(auctionDaily, deltaAuctionDaily);
        IAuction(auctionDaily).callIncomeTokensTrigger(delta);

        if (deltaAuctionWeekly > 0) {
        	IToken(mainToken).mint(auctionWeekly, deltaAuctionDaily);
            IAuction(auctionWeekly).callIncomeTokensTrigger(deltaAuctionWeekly);
        }

        IToken(mainToken).mint(bigPayDayPool, deltaPart);
        IToken(mainToken).mint(_msgSender(), amountOut);

        return true;
    }
}
