// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";
import "./@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IToken.sol";
import "./interfaces/IAuction.sol";

contract NativeSwap is AccessControl {
    using SafeMath for uint256;

    bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");

    uint256 public start;
    uint256 public stepTimestamp;
    uint256 public constant PERIOD = 350;

    address public swapToken;
    address public mainToken;
    address public auction;

    mapping(address => uint256) public swapTokenBalanceOf;

    modifier onlySetter() {
        require(hasRole(SETTER_ROLE, _msgSender()), "Caller is not a setter");
        _;
    }

    constructor(
        uint256 _stepTimestamp,
        address _swapToken,
        address _mainToken,
        address _setter
    ) public {
        _setupRole(SETTER_ROLE, _setter);
        start = now;
        stepTimestamp = _stepTimestamp;
        swapToken = _swapToken;
        mainToken = _mainToken;
    }

    function init(address _auction) external onlySetter {
        auction = _auction;
        renounceRole(SETTER_ROLE, _msgSender());
    }

    function deposit(uint256 _amount) public {
        IERC20(swapToken).transferFrom(msg.sender, address(this), _amount);

        swapTokenBalanceOf[msg.sender] = swapTokenBalanceOf[msg.sender].add(
            _amount
        );
    }

    function withdraw(uint256 _amount) public {
        require(_amount >= swapTokenBalanceOf[msg.sender], "balance < amount");

        swapTokenBalanceOf[msg.sender] = swapTokenBalanceOf[msg.sender].sub(
            _amount
        );
        IERC20(swapToken).transfer(msg.sender, _amount);
    }

    function swapNativeToken() external {
        uint256 amount = swapTokenBalanceOf[msg.sender];
        uint256 stepsFromStart = calculateStepsFromStart();
        uint256 delta = amount.mul(stepsFromStart).div(PERIOD);
        uint256 amountOut = amount.sub(delta);

        require(amount > 0, "amount <= 0");

        swapTokenBalanceOf[msg.sender] = 0;

        IToken(mainToken).mint(auction, delta);
        IAuction(auction).callIncomeTokensTrigger(delta);

        IToken(mainToken).mint(msg.sender, amountOut);
    }

    function calculateStepsFromStart() internal view returns (uint256) {
        return (now.sub(start)).div(stepTimestamp);
    }
}
