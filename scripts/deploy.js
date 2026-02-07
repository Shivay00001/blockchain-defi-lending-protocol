const hre = require("hardhat");

async function main() {
    console.log("Deploying DeFi Lending Protocol...\n");

    const [deployer] = await hre.ethers.getSigners();
    console.log("Deployer:", deployer.address);

    // 1. Deploy PriceOracle
    console.log("\n1. Deploying PriceOracle...");
    const PriceOracle = await hre.ethers.getContractFactory("PriceOracle");
    const priceOracle = await PriceOracle.deploy();
    await priceOracle.waitForDeployment();
    console.log("   PriceOracle:", await priceOracle.getAddress());

    // 2. Deploy InterestRateModel
    console.log("\n2. Deploying InterestRateModel...");
    const InterestRateModel = await hre.ethers.getContractFactory("InterestRateModel");
    const interestRateModel = await InterestRateModel.deploy(
        hre.ethers.parseUnits("2", 25),  // 2% base
        hre.ethers.parseUnits("4", 25),  // 4% slope1
        hre.ethers.parseUnits("75", 25), // 75% slope2
        hre.ethers.parseUnits("80", 25)  // 80% optimal
    );
    await interestRateModel.waitForDeployment();
    console.log("   InterestRateModel:", await interestRateModel.getAddress());

    // 3. Deploy LendingPool
    console.log("\n3. Deploying LendingPool...");
    const LendingPool = await hre.ethers.getContractFactory("LendingPool");
    const lendingPool = await LendingPool.deploy(await priceOracle.getAddress());
    await lendingPool.waitForDeployment();
    console.log("   LendingPool:", await lendingPool.getAddress());

    console.log("\n✅ Deployment Complete!");
    console.log("\nContract Addresses:");
    console.log("==================");
    console.log("PriceOracle:       ", await priceOracle.getAddress());
    console.log("InterestRateModel: ", await interestRateModel.getAddress());
    console.log("LendingPool:       ", await lendingPool.getAddress());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
