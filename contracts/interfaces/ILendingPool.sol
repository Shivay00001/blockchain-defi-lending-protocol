// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ILendingPool
 * @notice Interface for the LendingPool contract
 */
interface ILendingPool {
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
    ) external;
    
    /**
     * @notice Withdraw assets from the lending pool
     * @param asset The address of the underlying asset
     * @param amount The amount to withdraw
     * @param to The address that will receive the underlying
     * @return The actual amount withdrawn
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
    
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
    ) external;
    
    /**
     * @notice Repay borrowed assets
     * @param asset The address of the borrowed asset
     * @param amount The amount to repay
     * @param onBehalfOf The address of the borrower
     * @return The actual amount repaid
     */
    function repay(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external returns (uint256);
    
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
    ) external;
    
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
        );
    
    /**
     * @notice Calculate health factor for a user
     * @param user The user address
     * @return healthFactor The health factor
     */
    function calculateHealthFactor(address user) external view returns (uint256);
}
