// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";
import "./@openzeppelin/contracts/math/SafeMath.sol";

contract DepositToken is ERC20, AccessControl {
    using SafeMath for uint256;

    bytes32 private constant _MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private constant _ONE_DAY_TIMESTAMP = 86400;

    uint256 private _start;
    uint256 private _period;

    IERC20 private _swapToken;

    address private _transferTarget;

    mapping(address => uint256) private _swapTokenBalanceOf;

    constructor(
        string memory name,
        string memory symbol,
        address provider,
        uint256 period,
        address swapToken,
        address transferTarget
    ) public ERC20(name, symbol) {
        _setupRole(_MINTER_ROLE, provider);
        _start = now;
        _period = period;
        _swapToken = IERC20(swapToken);
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

    function getSwapToken() public view returns (IERC20) {
        return _swapToken;
    }

    function getPeriod() public view returns (uint256) {
        return _period;
    }

    function getSwapTokenBalanceOf(address _account)
        public
        view
        returns (uint256)
    {
        return _swapTokenBalanceOf[_account];
    }

    function getStart() public view returns (uint256) {
        return _start;
    }

    function mint(address to, uint256 amount) public returns (bool) {
        require(
            hasRole(getMinterRole(), _msgSender()),
            "Caller is not a minter"
        );
        _mint(to, amount);
    }

    function depositSwapToken(uint256 _amount) external returns (bool) {
        require(_swapToken.transferFrom(_msgSender(), address(this), _amount));

        _swapTokenBalanceOf[_msgSender()] = _swapTokenBalanceOf[_msgSender()]
            .add(_amount);
    }

    function withdrawSwapToken(uint256 _amount) external returns (bool) {
        require(_swapToken.transfer(_msgSender(), _amount));

        _swapTokenBalanceOf[_msgSender()] = _swapTokenBalanceOf[_msgSender()]
            .sub(_amount);
    }

    function swap() external returns (bool) {
        uint256 amount = _swapTokenBalanceOf[_msgSender()];
        uint256 daysFromStart = now.sub(_start).div(_ONE_DAY_TIMESTAMP);
        uint256 delta = amount.mul(daysFromStart).div(_period);
        uint256 amountOut = amount.sub(delta);

        require(amount > 0);

        _swapTokenBalanceOf[_msgSender()] = 0;

        _mint(_transferTarget, delta);
        _mint(_msgSender(), amountOut);

        return true;
    }
}
