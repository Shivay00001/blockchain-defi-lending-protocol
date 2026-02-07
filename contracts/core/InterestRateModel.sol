// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title InterestRateModel
 * @author Shivay Singh
 * @notice Interest rate model based on utilization rate
 * @dev Implements a two-slope interest rate model
 */
contract InterestRateModel {
    // All values in ray units (1e27)
    uint256 public constant RAY = 1e27;
    
    // Base rate (minimum rate when utilization is 0)
    uint256 public immutable baseRate;
    
    // Slope before optimal utilization
    uint256 public immutable slope1;
    
    // Slope after optimal utilization (steeper)
    uint256 public immutable slope2;
    
    // Optimal utilization rate (e.g., 80%)
    uint256 public immutable optimalUtilization;
    
    // Maximum borrow rate
    uint256 public immutable maxBorrowRate;
    
    /**
     * @notice Constructor
     * @param _baseRate Base interest rate (ray)
     * @param _slope1 Slope before optimal utilization (ray)
     * @param _slope2 Slope after optimal utilization (ray)
     * @param _optimalUtilization Optimal utilization rate (ray)
     */
    constructor(
        uint256 _baseRate,
        uint256 _slope1,
        uint256 _slope2,
        uint256 _optimalUtilization
    ) {
        baseRate = _baseRate;
        slope1 = _slope1;
        slope2 = _slope2;
        optimalUtilization = _optimalUtilization;
        maxBorrowRate = _baseRate + _slope1 + _slope2;
    }
    
    /**
     * @notice Calculate interest rates based on utilization
     * @param totalLiquidity Total liquidity in the pool
     * @param totalDebt Total borrowed amount
     * @return liquidityRate Rate earned by depositors (ray)
     * @return borrowRate Rate paid by borrowers (ray)
     */
    function calculateInterestRates(
        uint256 totalLiquidity,
        uint256 totalDebt
    ) external view returns (uint256 liquidityRate, uint256 borrowRate) {
        if (totalLiquidity == 0) {
            return (0, baseRate);
        }
        
        // Calculate utilization rate
        uint256 utilizationRate = totalDebt == 0 ? 0 : (totalDebt * RAY) / totalLiquidity;
        
        // Calculate borrow rate based on utilization
        if (utilizationRate <= optimalUtilization) {
            // Below optimal: linear increase with slope1
            borrowRate = baseRate + (utilizationRate * slope1) / optimalUtilization;
        } else {
            // Above optimal: steeper increase with slope2
            uint256 excessUtilization = utilizationRate - optimalUtilization;
            uint256 excessSlope = (excessUtilization * slope2) / (RAY - optimalUtilization);
            borrowRate = baseRate + slope1 + excessSlope;
        }
        
        // Cap at maximum rate
        if (borrowRate > maxBorrowRate) {
            borrowRate = maxBorrowRate;
        }
        
        // Liquidity rate = borrow rate * utilization * (1 - reserve factor)
        // Simplified: no reserve factor for now
        liquidityRate = (borrowRate * utilizationRate) / RAY;
        
        return (liquidityRate, borrowRate);
    }
    
    /**
     * @notice Get the utilization rate
     * @param totalLiquidity Total liquidity
     * @param totalDebt Total debt
     * @return utilizationRate The utilization rate (ray)
     */
    function getUtilizationRate(
        uint256 totalLiquidity,
        uint256 totalDebt
    ) external pure returns (uint256) {
        if (totalLiquidity == 0) {
            return 0;
        }
        return (totalDebt * RAY) / totalLiquidity;
    }
}
