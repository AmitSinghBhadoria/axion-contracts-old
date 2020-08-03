// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IToken.sol";

contract Staking {
    using SafeMath for uint256;

    struct Payout {
        uint256 amountPayout;
        uint256 sharesTotalSupply;
    }

    struct Staker {
        uint256 amountTokenIn;
        uint256 start;
        uint256 end;
        uint256 amountShares;
        bool stakerIsActive;
    }

    address public mainToken;
    uint256 public shareRate;
    uint256 public sharesTotalSupply;
    uint256 public lastMainTokenBalance;
    uint256 public nexPayotCall;

    uint256 public constant DAY = 86400;

    mapping(address => Staker) public stakers;
    Payout[] public payouts;

    constructor(address _mainToken) public {
        mainToken = _mainToken;
        shareRate = 1;
        lastMainTokenBalance = 0;
        nexPayotCall = now.add(DAY);
    }

    function stake(
        uint256 _amountTokenIn,
        uint256 _start,
        uint256 _end
    ) external {
        require(
            _end > _start && !stakers[msg.sender].stakerIsActive,
            "Wrong period or staker already exist"
        );
        IERC20(mainToken).transferFrom(
            msg.sender,
            address(this),
            _amountTokenIn
        );

        uint256 shares = _getStakersSharesAmount(_amountTokenIn, _start, _end);

        sharesTotalSupply = sharesTotalSupply.add(shares);

        stakers[msg.sender] = Staker({
            amountTokenIn: _amountTokenIn,
            start: _start,
            end: _end,
            amountShares: shares,
            stakerIsActive: true
        });
    }

    function unstake() external {
        require(stakers[msg.sender].stakerIsActive, "Staker is not active");

        uint256 accumulator;

        for (uint256 i = 0; i < payouts.length; i++) {
            uint256 payout = payouts[i]
                .amountPayout
                .mul(stakers[msg.sender].amountShares)
                .div(payouts[i].sharesTotalSupply);

            accumulator = accumulator.add(payout);
        }

        stakers[msg.sender].stakerIsActive = false;

        uint256 newShareRate = _getShareRate(
            accumulator,
            stakers[msg.sender].start,
            stakers[msg.sender].end
        );

        if (newShareRate > shareRate) {
            shareRate = newShareRate;
        }

        IERC20(mainToken).transfer(msg.sender, accumulator);
    }

    function makePayout() public {
        require(now >= nexPayotCall, "Wrong payout time");
        payouts.push(
            Payout({
                amountPayout: _getPayout(),
                sharesTotalSupply: sharesTotalSupply
            })
        );

        nexPayotCall = nexPayotCall.add(DAY);
    }

    function _getPayout() internal returns (uint256) {
        uint256 currentTokenBalance = IERC20(mainToken).balanceOf(
            address(this)
        );

        uint256 currentTokenTotalSupply = IERC20(mainToken).totalSupply();

        uint256 amountTokenInDay = currentTokenBalance.sub(
            lastMainTokenBalance
        );

        lastMainTokenBalance = currentTokenBalance;

        uint256 inflation = uint256(21087e16).mul(
            currentTokenTotalSupply.add(sharesTotalSupply)
        );

        IToken(mainToken).mint(address(this), inflation);

        return amountTokenInDay.add(inflation);
    }

    function _getStakersSharesAmount(
        uint256 amountTokenIn,
        uint256 start,
        uint256 end
    ) internal view returns (uint256) {
        uint256 coeff = uint256(1e18).add((end.sub(start).sub(1e18)).div(1820));
        return amountTokenIn.mul(coeff).div(shareRate);
    }

    function _getShareRate(
        uint256 accumulator,
        uint256 start,
        uint256 end
    ) internal view returns (uint256) {
        return
            (stakers[msg.sender].amountTokenIn.add(accumulator))
                .mul(uint256(1).add(end.sub(start).sub(1)).div(1820))
                .div(stakers[msg.sender].amountShares);
    }
}
