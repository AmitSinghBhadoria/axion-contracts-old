const BN = require("bn.js");
const chai = require("chai");
const { expect } = require("chai");
chai.use(require("chai-bn")(BN));

const SwapToken = artifacts.require("SwapToken");
const Token = artifacts.require("Token");
const NativeSwap = artifacts.require("NativeSwap");
const ForeignSwap = artifacts.require("ForeignSwap");
const UniswapV2Router02 = artifacts.require("UniswapV2Router02");
const Staking = artifacts.require("Staking");
const DailyAuction = artifacts.require("DailyAuction");
const WeeklyAuction = artifacts.require("WeeklyAuction");

const DAY = 86400;
const SUPPLY_LIMIT = web3.utils.toWei("1000");

contract("Token", ([setter]) => {
  let swaptoken;
  let token;
  let nativeswap;
  let foreigsnwap;
  let uniswapv2router02;
  let staking;
  let dailyauction;
  let weeklyauction;

  beforeEach(async () => {
    swaptoken = await SwapToken.new({ from: setter });
    token = await Token.new("Token", "TKN", swaptoken.address, setter);
    nativeswap = await NativeSwap.new(
      DAY,
      swaptoken.address,
      token.address,
      setter
    );
    foreigsnwap = await ForeignSwap.new(); // NC
    uniswapv2router02 = await UniswapV2Router02.new();
    staking = await Staking.new(); // NC
    dailyauction = await DailyAuction.new(
      DAY,
      SUPPLY_LIMIT,
      token.address,
      staking.address,
      uniswapv2router02.address,
      nativeswap.address,
      foreigsnwap.address,
      setter
    );
    weeklyauction = await WeeklyAuction.new(); // NC
  });

  it("should initDeposit", async () => {
    await swaptoken.approve(token.address, web3.utils.toWei("1000"), {
      from: setter,
    });

    await token.initDeposit(web3.utils.toWei("1000"), {
      from: setter,
    });

    expect(
      await token.swapTokenBalanceOf(setter)
    ).to.be.a.bignumber.that.equals(web3.utils.toWei("1000"));
  });

  it("should initWithdraw", async () => {
    await swaptoken.approve(token.address, web3.utils.toWei("1000"), {
      from: setter,
    });

    await token.initDeposit(web3.utils.toWei("1000"), {
      from: setter,
    });

    expect(
      await token.swapTokenBalanceOf(setter)
    ).to.be.a.bignumber.that.equals(web3.utils.toWei("1000"));

    await token.initWithdraw(web3.utils.toWei("1000"), {
      from: setter,
    });

    expect(
      await token.swapTokenBalanceOf(setter)
    ).to.be.a.bignumber.that.equals(web3.utils.toWei("0"));
  });

  it("should initSwap", async () => {
    await swaptoken.approve(token.address, web3.utils.toWei("1000"), {
      from: setter,
    });

    await token.initDeposit(web3.utils.toWei("1000"), {
      from: setter,
    });

    expect(
      await token.swapTokenBalanceOf(setter)
    ).to.be.a.bignumber.that.equals(web3.utils.toWei("1000"));

    await token.initSwap({
      from: setter,
    });

    expect(
      await token.swapTokenBalanceOf(setter)
    ).to.be.a.bignumber.that.equals(web3.utils.toWei("0"));

    expect(await token.balanceOf(setter)).to.be.a.bignumber.that.equals(
      web3.utils.toWei("1000")
    );
  });

  it("should init", async () => {
    // Call init only after swap!!!
    token.init(
      nativeswap.address,
      foreigsnwap.address,
      dailyauction.address,
      weeklyauction.address,
      { from: setter }
    );

    const MINTER_ROLE = await token.MINTER_ROLE();

    expect(await token.hasRole(MINTER_ROLE, nativeswap.address)).equals(true);
    expect(await token.hasRole(MINTER_ROLE, foreigsnwap.address)).equals(true);
    expect(await token.hasRole(MINTER_ROLE, dailyauction.address)).equals(true);
    expect(await token.hasRole(MINTER_ROLE, weeklyauction.address)).equals(
      true
    );
  });
});
