const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LendingPool", function () {
    let lendingPool, priceOracle, interestRateModel;
    let mockDAI, aDAI, debtDAI;
    let owner, user1, user2, liquidator;

    const DAI_PRICE = ethers.parseEther("1"); // $1
    const INITIAL_BALANCE = ethers.parseEther("10000");

    beforeEach(async function () {
        [owner, user1, user2, liquidator] = await ethers.getSigners();

        // Deploy PriceOracle
        const PriceOracle = await ethers.getContractFactory("PriceOracle");
        priceOracle = await PriceOracle.deploy();

        // Deploy InterestRateModel
        const InterestRateModel = await ethers.getContractFactory("InterestRateModel");
        interestRateModel = await InterestRateModel.deploy(
            ethers.parseUnits("2", 25),  // 2% base rate
            ethers.parseUnits("4", 25),  // 4% slope1
            ethers.parseUnits("75", 25), // 75% slope2
            ethers.parseUnits("80", 25)  // 80% optimal
        );

        // Deploy LendingPool
        const LendingPool = await ethers.getContractFactory("LendingPool");
        lendingPool = await LendingPool.deploy(await priceOracle.getAddress());

        // Deploy Mock DAI
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        mockDAI = await MockERC20.deploy("Mock DAI", "DAI", 18);

        // Deploy AToken
        const AToken = await ethers.getContractFactory("AToken");
        aDAI = await AToken.deploy("Aave DAI", "aDAI", await mockDAI.getAddress(), await lendingPool.getAddress());

        // Deploy DebtToken
        const DebtToken = await ethers.getContractFactory("DebtToken");
        debtDAI = await DebtToken.deploy("Debt DAI", "debtDAI", await mockDAI.getAddress(), await lendingPool.getAddress());

        // Setup
        await priceOracle.setAssetPrice(await mockDAI.getAddress(), DAI_PRICE);
        await lendingPool.initializeReserve(
            await mockDAI.getAddress(),
            await aDAI.getAddress(),
            await debtDAI.getAddress(),
            await interestRateModel.getAddress(),
            7500, // 75% LTV
            8000, // 80% liquidation threshold
            500   // 5% liquidation bonus
        );

        // Mint DAI to users
        await mockDAI.mint(user1.address, INITIAL_BALANCE);
        await mockDAI.mint(user2.address, INITIAL_BALANCE);
        await mockDAI.connect(user1).approve(await lendingPool.getAddress(), ethers.MaxUint256);
        await mockDAI.connect(user2).approve(await lendingPool.getAddress(), ethers.MaxUint256);
    });

    describe("Deposit", function () {
        it("should allow deposit", async function () {
            const depositAmount = ethers.parseEther("1000");
            await lendingPool.connect(user1).deposit(await mockDAI.getAddress(), depositAmount, user1.address);
            expect(await aDAI.balanceOf(user1.address)).to.be.gt(0);
        });

        it("should emit Deposit event", async function () {
            const depositAmount = ethers.parseEther("1000");
            await expect(lendingPool.connect(user1).deposit(await mockDAI.getAddress(), depositAmount, user1.address))
                .to.emit(lendingPool, "Deposit");
        });
    });

    describe("Withdraw", function () {
        beforeEach(async function () {
            await lendingPool.connect(user1).deposit(await mockDAI.getAddress(), ethers.parseEther("1000"), user1.address);
        });

        it("should allow withdrawal", async function () {
            const balanceBefore = await mockDAI.balanceOf(user1.address);
            await lendingPool.connect(user1).withdraw(await mockDAI.getAddress(), ethers.parseEther("500"), user1.address);
            expect(await mockDAI.balanceOf(user1.address)).to.be.gt(balanceBefore);
        });
    });

    describe("Health Factor", function () {
        it("should return max for user with no debt", async function () {
            await lendingPool.connect(user1).deposit(await mockDAI.getAddress(), ethers.parseEther("1000"), user1.address);
            const healthFactor = await lendingPool.calculateHealthFactor(user1.address);
            expect(healthFactor).to.equal(ethers.MaxUint256);
        });
    });
});
