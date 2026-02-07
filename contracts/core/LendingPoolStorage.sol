// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../oracle/PriceOracle.sol";

/**
 * @title LendingPoolStorage
 * @notice Storage layout for the LendingPool contract
 */
contract LendingPoolStorage {
    
    // Health factor threshold (1e18 = 1.0)
    uint256 public constant HEALTH_FACTOR_THRESHOLD = 1e18;
    
    // Reserve configuration
    struct ReserveData {
        // Addresses
        address aTokenAddress;
        address debtTokenAddress;
        address interestRateModel;
        
        // Indexes (ray units - 1e27)
        uint256 liquidityIndex;
        uint256 variableBorrowIndex;
        
        // Rates (ray units)
        uint256 currentLiquidityRate;
        uint256 currentVariableBorrowRate;
        
        // Timestamp
        uint40 lastUpdateTimestamp;
        
        // Risk parameters (basis points - 10000 = 100%)
        uint256 ltv;                    // Loan-to-value ratio
        uint256 liquidationThreshold;   // Threshold for liquidation
        uint256 liquidationBonus;       // Bonus for liquidators
        
        // Flags
        bool isActive;
        bool isFrozen;
    }
    
    // User configuration
    struct UserConfigurationMap {
        uint256 data;
    }
    
    // Price oracle
    PriceOracle public priceOracle;
    
    // Mapping of asset address to reserve data
    mapping(address => ReserveData) public reserves;
    
    // List of all reserve assets
    address[] public reservesList;
    
    // Mapping of user to their configuration
    mapping(address => UserConfigurationMap) internal userConfiguration;
    
    // Flash loan premium (basis points)
    uint256 public flashLoanPremium = 9; // 0.09%
    
    // Maximum number of reserves
    uint256 public constant MAX_RESERVES = 128;
}
