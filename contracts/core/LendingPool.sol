// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "./LendingPoolStorage.sol";
import "./InterestRateModel.sol";
import "../tokens/AToken.sol";
import "../tokens/DebtToken.sol";
import "../oracle/PriceOracle.sol";
import "../interfaces/ILendingPool.sol";

/**
 * @title LendingPool
 * @author Shivay Singh
 * @notice Main entry point for the DeFi lending protocol
 * @dev Manages deposits, withdrawals, borrows, repayments, and liquidations
 */
contract LendingPool is ILendingPool, LendingPoolStorage, ReentrancyGuard, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");

    // Events
    event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 aTokensMinted);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Liquidation(
        address indexed liquidator,
        address indexed borrower,
        address indexed collateralAsset,
        address debtAsset,
        uint256 debtCovered,
        uint256 collateralSeized
    );
    event ReserveInitialized(address indexed asset, address aToken, address debtToken);

    modifier onlyValidAsset(address asset) {
        require(reserves[asset].isActive, "LendingPool: Asset not supported");
        _;
    }

    constructor(address _priceOracle) {
        priceOracle = PriceOracle(_priceOracle);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Initialize a new lending reserve for an asset
     * @param asset The underlying asset address
     * @param aToken The corresponding aToken address
     * @param debtToken The corresponding debt token address
     * @param interestRateModel The interest rate model contract
     * @param ltv Loan-to-value ratio (in basis points, e.g., 7500 = 75%)
     * @param liquidationThreshold Threshold for liquidation (basis points)
     * @param liquidationBonus Bonus for liquidators (basis points)
     */
    function initializeReserve(
        address asset,
        address aToken,
        address debtToken,
        address interestRateModel,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) external onlyRole(ADMIN_ROLE) {
        require(!reserves[asset].isActive, "LendingPool: Reserve already initialized");
        
        reserves[asset] = ReserveData({
            aTokenAddress: aToken,
            debtTokenAddress: debtToken,
            interestRateModel: interestRateModel,
            liquidityIndex: 1e27,
            variableBorrowIndex: 1e27,
            currentLiquidityRate: 0,
            currentVariableBorrowRate: 0,
            lastUpdateTimestamp: uint40(block.timestamp),
            ltv: ltv,
            liquidationThreshold: liquidationThreshold,
            liquidationBonus: liquidationBonus,
            isActive: true,
            isFrozen: false
        });

        reservesList.push(asset);
        emit ReserveInitialized(asset, aToken, debtToken);
    }

    /**
     * @notice Deposit assets into the lending pool
     * @param asset The address of the underlying asset
     * @param amount The amount to deposit
     * @param onBehalfOf The address that will receive the aTokens
     */
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external override nonReentrant whenNotPaused onlyValidAsset(asset) {
        require(amount > 0, "LendingPool: Invalid amount");
        require(!reserves[asset].isFrozen, "LendingPool: Reserve is frozen");

        ReserveData storage reserve = reserves[asset];
        
        // Update reserve state
        _updateState(asset);

        // Transfer underlying asset from user
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Mint aTokens to user
        uint256 aTokensToMint = _calculateATokenAmount(amount, reserve.liquidityIndex);
        AToken(reserve.aTokenAddress).mint(onBehalfOf, aTokensToMint);

        emit Deposit(onBehalfOf, asset, amount, aTokensToMint);
    }

    /**
     * @notice Withdraw assets from the lending pool
     * @param asset The address of the underlying asset
     * @param amount The amount to withdraw (use type(uint256).max for max)
     * @param to The address that will receive the underlying asset
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external override nonReentrant onlyValidAsset(asset) returns (uint256) {
        ReserveData storage reserve = reserves[asset];
        
        _updateState(asset);

        uint256 userBalance = AToken(reserve.aTokenAddress).balanceOf(msg.sender);
        uint256 amountToWithdraw = amount == type(uint256).max ? userBalance : amount;

        require(amountToWithdraw <= userBalance, "LendingPool: Insufficient balance");

        // Check health factor after withdrawal
        require(
            _healthFactorAfterWithdraw(msg.sender, asset, amountToWithdraw) >= HEALTH_FACTOR_THRESHOLD,
            "LendingPool: Withdrawal would cause undercollateralization"
        );

        // Burn aTokens
        AToken(reserve.aTokenAddress).burn(msg.sender, amountToWithdraw);

        // Transfer underlying to user
        IERC20(asset).safeTransfer(to, amountToWithdraw);

        emit Withdraw(msg.sender, asset, amountToWithdraw);
        return amountToWithdraw;
    }

    /**
     * @notice Borrow assets from the lending pool
     * @param asset The address of the asset to borrow
     * @param amount The amount to borrow
     * @param onBehalfOf The address that will receive the debt
     */
    function borrow(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external override nonReentrant whenNotPaused onlyValidAsset(asset) {
        require(amount > 0, "LendingPool: Invalid amount");
        require(!reserves[asset].isFrozen, "LendingPool: Reserve is frozen");

        ReserveData storage reserve = reserves[asset];
        
        _updateState(asset);

        // Check if user has sufficient collateral
        require(
            _healthFactorAfterBorrow(onBehalfOf, asset, amount) >= HEALTH_FACTOR_THRESHOLD,
            "LendingPool: Insufficient collateral"
        );

        // Mint debt tokens
        DebtToken(reserve.debtTokenAddress).mint(onBehalfOf, amount);

        // Transfer borrowed asset
        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Borrow(onBehalfOf, asset, amount);
    }

    /**
     * @notice Repay borrowed assets
     * @param asset The address of the borrowed asset
     * @param amount The amount to repay (use type(uint256).max for full repayment)
     * @param onBehalfOf The address of the borrower
     */
    function repay(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external override nonReentrant onlyValidAsset(asset) returns (uint256) {
        ReserveData storage reserve = reserves[asset];
        
        _updateState(asset);

        uint256 userDebt = DebtToken(reserve.debtTokenAddress).balanceOf(onBehalfOf);
        uint256 paybackAmount = amount == type(uint256).max ? userDebt : amount;
        paybackAmount = paybackAmount > userDebt ? userDebt : paybackAmount;

        require(paybackAmount > 0, "LendingPool: Nothing to repay");

        // Transfer asset from user
        IERC20(asset).safeTransferFrom(msg.sender, address(this), paybackAmount);

        // Burn debt tokens
        DebtToken(reserve.debtTokenAddress).burn(onBehalfOf, paybackAmount);

        emit Repay(onBehalfOf, asset, paybackAmount);
        return paybackAmount;
    }

    /**
     * @notice Liquidate an undercollateralized position
     * @param collateralAsset The collateral asset to seize
     * @param debtAsset The debt asset to repay
     * @param borrower The borrower to liquidate
     * @param debtToCover The amount of debt to cover
     */
    function liquidate(
        address collateralAsset,
        address debtAsset,
        address borrower,
        uint256 debtToCover
    ) external override nonReentrant whenNotPaused {
        require(collateralAsset != debtAsset, "LendingPool: Cannot liquidate same asset");
        
        // Check borrower's health factor
        uint256 healthFactor = calculateHealthFactor(borrower);
        require(healthFactor < HEALTH_FACTOR_THRESHOLD, "LendingPool: Position is healthy");

        ReserveData storage collateralReserve = reserves[collateralAsset];
        ReserveData storage debtReserve = reserves[debtAsset];

        _updateState(collateralAsset);
        _updateState(debtAsset);

        // Calculate debt to cover (max 50% of position)
        uint256 userDebt = DebtToken(debtReserve.debtTokenAddress).balanceOf(borrower);
        uint256 maxDebtToCover = (userDebt * 5000) / 10000; // 50%
        uint256 actualDebtToCover = debtToCover > maxDebtToCover ? maxDebtToCover : debtToCover;

        // Calculate collateral to seize (with bonus)
        uint256 collateralToSeize = _calculateCollateralToSeize(
            collateralAsset,
            debtAsset,
            actualDebtToCover,
            collateralReserve.liquidationBonus
        );

        // Transfer debt from liquidator
        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), actualDebtToCover);

        // Burn borrower's debt
        DebtToken(debtReserve.debtTokenAddress).burn(borrower, actualDebtToCover);

        // Transfer collateral to liquidator
        AToken(collateralReserve.aTokenAddress).transferOnLiquidation(
            borrower,
            msg.sender,
            collateralToSeize
        );

        emit Liquidation(
            msg.sender,
            borrower,
            collateralAsset,
            debtAsset,
            actualDebtToCover,
            collateralToSeize
        );
    }

    /**
     * @notice Calculate health factor for a user
     * @param user The user address
     * @return healthFactor The health factor (1e18 = 1.0)
     */
    function calculateHealthFactor(address user) public view returns (uint256) {
        (uint256 totalCollateralUSD, uint256 totalDebtUSD) = _getUserAccountData(user);
        
        if (totalDebtUSD == 0) {
            return type(uint256).max;
        }
        
        return (totalCollateralUSD * 1e18) / totalDebtUSD;
    }

    /**
     * @notice Get user account data
     * @param user The user address
     */
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,
            uint256 availableBorrowsUSD,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        (totalCollateralUSD, totalDebtUSD) = _getUserAccountData(user);
        healthFactor = calculateHealthFactor(user);
        
        // Simplified LTV calculation
        ltv = 7500; // 75% default
        currentLiquidationThreshold = 8000; // 80%
        
        if (totalCollateralUSD > 0) {
            availableBorrowsUSD = (totalCollateralUSD * ltv / 10000) - totalDebtUSD;
        }
    }

    // ============ Internal Functions ============

    function _updateState(address asset) internal {
        ReserveData storage reserve = reserves[asset];
        
        uint256 timeDelta = block.timestamp - reserve.lastUpdateTimestamp;
        if (timeDelta == 0) {
            return;
        }

        // Update indexes based on interest accrued
        InterestRateModel rateModel = InterestRateModel(reserve.interestRateModel);
        
        uint256 totalDebt = DebtToken(reserve.debtTokenAddress).totalSupply();
        uint256 totalLiquidity = IERC20(asset).balanceOf(address(this)) + totalDebt;
        
        (uint256 liquidityRate, uint256 borrowRate) = rateModel.calculateInterestRates(
            totalLiquidity,
            totalDebt
        );

        reserve.currentLiquidityRate = liquidityRate;
        reserve.currentVariableBorrowRate = borrowRate;
        reserve.lastUpdateTimestamp = uint40(block.timestamp);
    }

    function _calculateATokenAmount(uint256 amount, uint256 index) internal pure returns (uint256) {
        return (amount * 1e27) / index;
    }

    function _getUserAccountData(address user) internal view returns (uint256 totalCollateral, uint256 totalDebt) {
        for (uint256 i = 0; i < reservesList.length; i++) {
            address asset = reservesList[i];
            ReserveData storage reserve = reserves[asset];
            
            uint256 assetPrice = priceOracle.getAssetPrice(asset);
            
            // Collateral value
            uint256 aTokenBalance = AToken(reserve.aTokenAddress).balanceOf(user);
            uint256 collateralValue = (aTokenBalance * assetPrice) / 1e18;
            totalCollateral += (collateralValue * reserve.liquidationThreshold) / 10000;
            
            // Debt value
            uint256 debtBalance = DebtToken(reserve.debtTokenAddress).balanceOf(user);
            totalDebt += (debtBalance * assetPrice) / 1e18;
        }
    }

    function _healthFactorAfterWithdraw(
        address user,
        address asset,
        uint256 amount
    ) internal view returns (uint256) {
        (uint256 totalCollateral, uint256 totalDebt) = _getUserAccountData(user);
        
        uint256 assetPrice = priceOracle.getAssetPrice(asset);
        uint256 withdrawValue = (amount * assetPrice) / 1e18;
        uint256 adjustedValue = (withdrawValue * reserves[asset].liquidationThreshold) / 10000;
        
        if (totalDebt == 0) {
            return type(uint256).max;
        }
        
        return ((totalCollateral - adjustedValue) * 1e18) / totalDebt;
    }

    function _healthFactorAfterBorrow(
        address user,
        address asset,
        uint256 amount
    ) internal view returns (uint256) {
        (uint256 totalCollateral, uint256 totalDebt) = _getUserAccountData(user);
        
        uint256 assetPrice = priceOracle.getAssetPrice(asset);
        uint256 borrowValue = (amount * assetPrice) / 1e18;
        
        if (totalDebt + borrowValue == 0) {
            return type(uint256).max;
        }
        
        return (totalCollateral * 1e18) / (totalDebt + borrowValue);
    }

    function _calculateCollateralToSeize(
        address collateralAsset,
        address debtAsset,
        uint256 debtAmount,
        uint256 liquidationBonus
    ) internal view returns (uint256) {
        uint256 debtPrice = priceOracle.getAssetPrice(debtAsset);
        uint256 collateralPrice = priceOracle.getAssetPrice(collateralAsset);
        
        uint256 debtValueUSD = (debtAmount * debtPrice) / 1e18;
        uint256 collateralToSeize = (debtValueUSD * 1e18) / collateralPrice;
        
        // Add liquidation bonus
        return (collateralToSeize * (10000 + liquidationBonus)) / 10000;
    }

    // ============ Admin Functions ============

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function freezeReserve(address asset) external onlyRole(ADMIN_ROLE) {
        reserves[asset].isFrozen = true;
    }

    function unfreezeReserve(address asset) external onlyRole(ADMIN_ROLE) {
        reserves[asset].isFrozen = false;
    }
}
