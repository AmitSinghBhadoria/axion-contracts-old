// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";
import "./@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IToken.sol";

contract Token is IToken, ERC20, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");

    address public swapToken;

    mapping(address => uint256) public swapTokenBalanceOf;

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), "Caller is not a minter");
        _;
    }

    modifier onlySetter() {
        require(hasRole(SETTER_ROLE, _msgSender()), "Caller is not a setter");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _swapToken,
        address _setter
    ) public ERC20(_name, _symbol) {
        _setupRole(SETTER_ROLE, _setter);
        swapToken = _swapToken;
    }

    // Call only after initSwap!!!
    function init(
        address NativeSwap,
        address ForeignSwap,
        address DailyAuction,
        address WeeklyAuction
    ) external onlySetter {
        _setupRole(MINTER_ROLE, NativeSwap);
        _setupRole(MINTER_ROLE, ForeignSwap);
        _setupRole(MINTER_ROLE, DailyAuction);
        _setupRole(MINTER_ROLE, WeeklyAuction);

        renounceRole(SETTER_ROLE, _msgSender());
    }

    function initDeposit(uint256 _amount) external onlySetter {
        IERC20(swapToken).transferFrom(_msgSender(), address(this), _amount);

        swapTokenBalanceOf[_msgSender()] = swapTokenBalanceOf[_msgSender()].add(
            _amount
        );
    }

    function initWithdraw(uint256 _amount) external onlySetter {
        require(
            _amount >= swapTokenBalanceOf[_msgSender()],
            "balance < amount"
        );

        swapTokenBalanceOf[_msgSender()] = swapTokenBalanceOf[_msgSender()].sub(
            _amount
        );

        IERC20(swapToken).transfer(_msgSender(), _amount);
    }

    function initSwap() external onlySetter {
        uint256 balance = swapTokenBalanceOf[_msgSender()];

        require(balance > 0, "balance <= 0");

        swapTokenBalanceOf[_msgSender()] = 0;

        _mint(_msgSender(), balance);
    }

    function mint(address to, uint256 amount) external override onlyMinter {
        _mint(to, amount);
    }
}
