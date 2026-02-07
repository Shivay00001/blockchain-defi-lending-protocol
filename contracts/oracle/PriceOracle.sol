// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PriceOracle
 * @author Shivay Singh
 * @notice Price oracle for asset valuations
 * @dev In production, integrate with Chainlink or other reliable oracles
 */
contract PriceOracle is Ownable {
    // Mapping from asset address to price (in USD with 18 decimals)
    mapping(address => uint256) private assetPrices;
    
    // Fallback oracle (e.g., Chainlink)
    address public fallbackOracle;
    
    // Events
    event AssetPriceUpdated(address indexed asset, uint256 price);
    event FallbackOracleUpdated(address indexed newOracle);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @notice Set the price for an asset
     * @param asset The asset address
     * @param price The price in USD (18 decimals, e.g., 1e18 = $1)
     */
    function setAssetPrice(address asset, uint256 price) external onlyOwner {
        require(asset != address(0), "PriceOracle: Invalid asset");
        require(price > 0, "PriceOracle: Invalid price");
        
        assetPrices[asset] = price;
        emit AssetPriceUpdated(asset, price);
    }
    
    /**
     * @notice Set prices for multiple assets
     * @param assets Array of asset addresses
     * @param prices Array of prices
     */
    function setAssetPrices(
        address[] calldata assets,
        uint256[] calldata prices
    ) external onlyOwner {
        require(assets.length == prices.length, "PriceOracle: Length mismatch");
        
        for (uint256 i = 0; i < assets.length; i++) {
            require(assets[i] != address(0), "PriceOracle: Invalid asset");
            require(prices[i] > 0, "PriceOracle: Invalid price");
            
            assetPrices[assets[i]] = prices[i];
            emit AssetPriceUpdated(assets[i], prices[i]);
        }
    }
    
    /**
     * @notice Get the price of an asset
     * @param asset The asset address
     * @return The price in USD (18 decimals)
     */
    function getAssetPrice(address asset) external view returns (uint256) {
        uint256 price = assetPrices[asset];
        
        if (price == 0 && fallbackOracle != address(0)) {
            // Try fallback oracle
            return PriceOracle(fallbackOracle).getAssetPrice(asset);
        }
        
        require(price > 0, "PriceOracle: Price not set");
        return price;
    }
    
    /**
     * @notice Get prices for multiple assets
     * @param assets Array of asset addresses
     * @return prices Array of prices
     */
    function getAssetPrices(address[] calldata assets) 
        external 
        view 
        returns (uint256[] memory prices) 
    {
        prices = new uint256[](assets.length);
        
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 price = assetPrices[assets[i]];
            
            if (price == 0 && fallbackOracle != address(0)) {
                price = PriceOracle(fallbackOracle).getAssetPrice(assets[i]);
            }
            
            prices[i] = price;
        }
        
        return prices;
    }
    
    /**
     * @notice Set the fallback oracle
     * @param _fallbackOracle The fallback oracle address
     */
    function setFallbackOracle(address _fallbackOracle) external onlyOwner {
        fallbackOracle = _fallbackOracle;
        emit FallbackOracleUpdated(_fallbackOracle);
    }
    
    /**
     * @notice Check if a price is available for an asset
     * @param asset The asset address
     * @return True if price is available
     */
    function hasPrice(address asset) external view returns (bool) {
        return assetPrices[asset] > 0;
    }
}
