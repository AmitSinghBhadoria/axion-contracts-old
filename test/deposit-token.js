const DepositToken = artifacts.require("DepositToken");
const Token = artifacts.require("Token");

const chai = require("chai");
const BN = require("bn.js");
const { expect } = require("chai");
const helper = require("./utils/utils.js");

chai.use(require("chai-bn")(BN));

const tokenAmount = new BN("100000000000000000000", 10);
const tokenAmount175 = new BN("100000000000000000000", 10).div(new BN("2", 10));
const SECONDS_IN_DAY = 86400;

contract("DepositToken", ([acc1, acc2, acc3]) => {
  let DepositTokenInstance;
  let TokenInstance;

  beforeEach("setup contracts instances", async () => {
    TokenInstance = await Token.new();

    DepositTokenInstance = await DepositToken.new(
      "DepositToken",
      "DTK",
      acc3,
      new BN("350", 10),
      TokenInstance.address,
      acc2
    );
  });

  it("should deposit swap tokens", async () => {
    await TokenInstance.approve(DepositTokenInstance.address, tokenAmount, {
      from: acc1,
    });

    await DepositTokenInstance.depositSwapToken(tokenAmount, { from: acc1 });

    const swapTokenBalance = await DepositTokenInstance.getSwapTokenBalanceOf(
      acc1
    );

    expect(swapTokenBalance).to.be.a.bignumber.that.equals(tokenAmount);
  });

  it("should withdraw swap tokens", async () => {
    await TokenInstance.approve(DepositTokenInstance.address, tokenAmount, {
      from: acc1,
    });

    await DepositTokenInstance.depositSwapToken(tokenAmount, { from: acc1 });

    await DepositTokenInstance.withdrawSwapToken(
      tokenAmount.div(new BN("2", 10)),
      {
        from: acc1,
      }
    );

    const swapTokenBalance = await DepositTokenInstance.getSwapTokenBalanceOf(
      acc1
    );

    expect(swapTokenBalance).to.be.a.bignumber.that.equals(
      tokenAmount.div(new BN("2", 10))
    );
  });

  it("should swap tokens", async () => {
    await TokenInstance.approve(DepositTokenInstance.address, tokenAmount, {
      from: acc1,
    });

    await DepositTokenInstance.depositSwapToken(tokenAmount, { from: acc1 });
    await DepositTokenInstance.swap({ from: acc1 });

    const swapTokenBalance = await DepositTokenInstance.getSwapTokenBalanceOf(
      acc1
    );

    const balanceAcc1 = await DepositTokenInstance.balanceOf(acc1);
    const balanceAcc2 = await DepositTokenInstance.balanceOf(acc2);

    expect(swapTokenBalance).to.be.a.bignumber.that.equals(new BN("0", 10));
    expect(balanceAcc1).to.be.a.bignumber.that.equals(tokenAmount);
    expect(balanceAcc2).to.be.a.bignumber.that.equals(new BN("0", 10));
  });

  it("should swap tokens after 175 days", async () => {
    await helper.advanceTimeAndBlock(SECONDS_IN_DAY * 175);

    await TokenInstance.approve(DepositTokenInstance.address, tokenAmount, {
      from: acc1,
    });

    await DepositTokenInstance.depositSwapToken(tokenAmount, { from: acc1 });
    await DepositTokenInstance.swap({ from: acc1 });

    const swapTokenBalance = await DepositTokenInstance.getSwapTokenBalanceOf(
      acc1
    );

    const balanceAcc1 = await DepositTokenInstance.balanceOf(acc1);
    const balanceAcc2 = await DepositTokenInstance.balanceOf(acc2);

    expect(swapTokenBalance).to.be.a.bignumber.that.equals(new BN("0", 10));
    expect(balanceAcc1).to.be.a.bignumber.that.equals(tokenAmount175);
    expect(balanceAcc2).to.be.a.bignumber.that.equals(tokenAmount175);
  });

  it("should swap tokens after 350 days", async () => {
    await helper.advanceTimeAndBlock(SECONDS_IN_DAY * 350);

    await TokenInstance.approve(DepositTokenInstance.address, tokenAmount, {
      from: acc1,
    });

    await DepositTokenInstance.depositSwapToken(tokenAmount, { from: acc1 });
    await DepositTokenInstance.swap({ from: acc1 });

    const swapTokenBalance = await DepositTokenInstance.getSwapTokenBalanceOf(
      acc1
    );

    const balanceAcc1 = await DepositTokenInstance.balanceOf(acc1);
    const balanceAcc2 = await DepositTokenInstance.balanceOf(acc2);

    expect(swapTokenBalance).to.be.a.bignumber.that.equals(new BN("0", 10));
    expect(balanceAcc1).to.be.a.bignumber.that.equals(new BN("0", 10));
    expect(balanceAcc2).to.be.a.bignumber.that.equals(tokenAmount);
  });
});
