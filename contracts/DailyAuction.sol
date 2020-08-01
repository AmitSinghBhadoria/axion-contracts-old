// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IToken.sol";

contract DailyAuction is AccessControl {
    using SafeMath for uint256;

    struct AuctionReserves {
        uint256 eth;
        uint256 token;
    }

    struct UserBet {
        uint256 eth;
        address ref;
    }

    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");

    // Auction reserves
    mapping(uint256 => AuctionReserves) public reservesOf;
    // User auctions
    mapping(address => uint256[]) public auctionsOf;
    // Control of user auctions (for _auctionsOf dublicates)
    mapping(uint256 => mapping(address => bool)) public existAuctionsOf;
    // User ETH balance in auction
    mapping(uint256 => mapping(address => UserBet)) public auctionEthBalanceOf;

    uint256 public start;
    uint256 public stepTimestamp;
    uint256 public currentAuctionId;
    uint256 public supplyLimit;

    address public staking;
    address public mainToken;
    address payable public uniswap;
    address payable public recipient;

    constructor(
        uint256 _stepTimestamp,
        uint256 _supplyLimit,
        address _mainToken,
        address _staking,
        address payable _uniswap,
        address _nativeSwap,
        address _foreignSwap,
        address payable _recipient
    ) public {
        _setupRole(CALLER_ROLE, _nativeSwap);
        _setupRole(CALLER_ROLE, _foreignSwap);
        recipient = _recipient;
        start = now;
        mainToken = _mainToken;
        uniswap = _uniswap;
        stepTimestamp = _stepTimestamp;
        staking = _staking;
        supplyLimit = _supplyLimit;
    }

    function getUserEthBalanceInAuction(uint256 auctionId, address account)
        public
        view
        returns (uint256)
    {
        return auctionEthBalanceOf[auctionId][account].eth;
    }

    function getUserRefInAuction(uint256 auctionId, address account)
        public
        view
        returns (address)
    {
        return auctionEthBalanceOf[auctionId][account].ref;
    }

    function bet(
        address[] calldata path,
        uint256 deadline,
        address ref
    ) external payable {
        require(_msgSender() != ref, "msg.sender == ref");

        (uint256 toRecipient, uint256 toUniswap) = _calculateAmountsToSend();

        if (!_swapEth(path, toUniswap, deadline)) {
            revert();
        }

        uint256 stepsFromStart = calculateStepsFromStart();

        currentAuctionId = stepsFromStart;

        auctionEthBalanceOf[stepsFromStart][_msgSender()].ref = ref;

        auctionEthBalanceOf[stepsFromStart][_msgSender()]
            .eth = auctionEthBalanceOf[stepsFromStart][_msgSender()].eth.add(
            msg.value
        );

        // Control of user auctions
        if (!existAuctionsOf[stepsFromStart][_msgSender()]) {
            auctionsOf[_msgSender()].push(stepsFromStart);
            existAuctionsOf[stepsFromStart][_msgSender()] = true;
        }

        reservesOf[stepsFromStart].eth = reservesOf[stepsFromStart].eth.add(
            msg.value
        );

        IERC20(mainToken).transfer(recipient, toRecipient);
    }

    function withdraw(uint256 auctionId) external payable returns (bool) {
        uint256 stepsFromStart = calculateStepsFromStart();

        require(stepsFromStart > auctionId, "auction is active");


            uint256 auctionETHUserBalance
         = auctionEthBalanceOf[auctionId][_msgSender()].eth;

        require(auctionETHUserBalance > 0, "zero balance");

        uint256 amountTokenToSend = calculateAmountTokenToSend(
            auctionId,
            auctionETHUserBalance
        );

        auctionEthBalanceOf[auctionId][_msgSender()].eth = 0;

        if (
            address(auctionEthBalanceOf[auctionId][_msgSender()].ref) ==
            address(0)
        ) {
            IERC20(mainToken).transfer(_msgSender(), amountTokenToSend);
        } else {
            uint256 refDelta = amountTokenToSend.mul(20).div(100);
            uint256 refReward = amountTokenToSend.mul(10).div(100);

            IERC20(mainToken).transfer(
                _msgSender(),
                amountTokenToSend.add(refDelta)
            );

            if (supplyLimit > IERC20(mainToken).totalSupply()) {
                IToken(mainToken).mint(
                    address(auctionEthBalanceOf[auctionId][_msgSender()].ref),
                    amountTokenToSend.add(refReward)
                );
            }
        }
    }

    function calculateAmountTokenToSend(uint256 auctionId, uint256 amountEth)
        public
        view
        returns (uint256)
    {
        uint256 auctionReserveEth = reservesOf[auctionId].eth;
        uint256 auctionReserveToken = reservesOf[auctionId].token;

        return amountEth.mul(auctionReserveToken).div(auctionReserveEth);
    }

    function callIncomeTokensTrigger(uint256 incomeAmountToken)
        external
        returns (bool)
    {
        require(
            hasRole(CALLER_ROLE, _msgSender()),
            "Caller is not a caller role"
        );

        uint256 stepsFromStart = calculateStepsFromStart();

        reservesOf[stepsFromStart].token = reservesOf[stepsFromStart].token.add(
            incomeAmountToken
        );

        return true;
    }

    function calculateStepsFromStart() public view returns (uint256) {
        return now.sub(start).div(stepTimestamp);
    }

    function _calculateAmountsToSend() private returns (uint256, uint256) {
        uint256 toRecipient = msg.value.mul(20).div(100);
        uint256 toUniswap = msg.value.sub(toRecipient);

        return (toRecipient, toUniswap);
    }

    function _swapEth(
        address[] memory path,
        uint256 amount,
        uint256 deadline
    ) private returns (bool) {
        require(path[0] == IUniswapV2Router02(uniswap).WETH(), "wrong 0 path");
        require(path[1] == mainToken, "wrong 1 path");

        uint256 amountOutMin = IUniswapV2Router02(uniswap).getAmountsOut(
            amount,
            path
        )[1];

        IUniswapV2Router02(uniswap).swapExactETHForTokens{value: amount}(
            amountOutMin,
            path,
            staking,
            deadline
        );

        return true;
    }
}
