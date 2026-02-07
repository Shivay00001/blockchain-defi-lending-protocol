// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AToken
 * @author Shivay Singh
 * @notice Interest-bearing token representing deposits in the lending pool
 * @dev Each underlying asset has a corresponding aToken
 */
contract AToken is ERC20, Ownable {
    // The underlying asset
    address public immutable underlyingAsset;
    
    // The lending pool contract
    address public lendingPool;
    
    // Events
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event TransferOnLiquidation(address indexed from, address indexed to, uint256 amount);
    
    modifier onlyLendingPool() {
        require(msg.sender == lendingPool, "AToken: Only lending pool");
        _;
    }
    
    /**
     * @notice Constructor
     * @param name Token name (e.g., "Aave Interest bearing DAI")
     * @param symbol Token symbol (e.g., "aDAI")
     * @param _underlyingAsset The underlying asset address
     * @param _lendingPool The lending pool address
     */
    constructor(
        string memory name,
        string memory symbol,
        address _underlyingAsset,
        address _lendingPool
    ) ERC20(name, symbol) Ownable(msg.sender) {
        underlyingAsset = _underlyingAsset;
        lendingPool = _lendingPool;
    }
    
    /**
     * @notice Mint aTokens to a user
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyLendingPool {
        _mint(to, amount);
        emit Mint(to, amount);
    }
    
    /**
     * @notice Burn aTokens from a user
     * @param from User address
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external onlyLendingPool {
        _burn(from, amount);
        emit Burn(from, amount);
    }
    
    /**
     * @notice Transfer aTokens during liquidation
     * @param from Borrower being liquidated
     * @param to Liquidator
     * @param amount Amount to transfer
     */
    function transferOnLiquidation(
        address from,
        address to,
        uint256 amount
    ) external onlyLendingPool {
        _transfer(from, to, amount);
        emit TransferOnLiquidation(from, to, amount);
    }
    
    /**
     * @notice Update the lending pool address
     * @param newLendingPool New lending pool address
     */
    function setLendingPool(address newLendingPool) external onlyOwner {
        require(newLendingPool != address(0), "AToken: Invalid address");
        lendingPool = newLendingPool;
    }
    
    /**
     * @notice Get scaled balance (balance at current index)
     * @param user User address
     * @return Scaled balance
     */
    function scaledBalanceOf(address user) external view returns (uint256) {
        return balanceOf(user);
    }
    
    /**
     * @notice Get scaled total supply
     * @return Scaled total supply
     */
    function scaledTotalSupply() external view returns (uint256) {
        return totalSupply();
    }
}
