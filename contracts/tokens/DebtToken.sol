// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DebtToken
 * @author Shivay Singh
 * @notice Token representing user debt in the lending protocol
 * @dev Non-transferable token that tracks borrowed amounts
 */
contract DebtToken is ERC20, Ownable {
    // The underlying borrowed asset
    address public immutable underlyingAsset;
    
    // The lending pool contract
    address public lendingPool;
    
    // Events
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    
    modifier onlyLendingPool() {
        require(msg.sender == lendingPool, "DebtToken: Only lending pool");
        _;
    }
    
    /**
     * @notice Constructor
     * @param name Token name (e.g., "Variable Debt DAI")
     * @param symbol Token symbol (e.g., "variableDebtDAI")
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
     * @notice Mint debt tokens when user borrows
     * @param to Borrower address
     * @param amount Amount borrowed
     */
    function mint(address to, uint256 amount) external onlyLendingPool {
        _mint(to, amount);
        emit Mint(to, amount);
    }
    
    /**
     * @notice Burn debt tokens when user repays
     * @param from Borrower address
     * @param amount Amount repaid
     */
    function burn(address from, uint256 amount) external onlyLendingPool {
        _burn(from, amount);
        emit Burn(from, amount);
    }
    
    /**
     * @notice Update the lending pool address
     * @param newLendingPool New lending pool address
     */
    function setLendingPool(address newLendingPool) external onlyOwner {
        require(newLendingPool != address(0), "DebtToken: Invalid address");
        lendingPool = newLendingPool;
    }
    
    /**
     * @notice Override transfer to make tokens non-transferable
     * @dev Debt tokens cannot be transferred between users
     */
    function transfer(address, uint256) public pure override returns (bool) {
        revert("DebtToken: Transfer not allowed");
    }
    
    /**
     * @notice Override transferFrom to make tokens non-transferable
     */
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert("DebtToken: Transfer not allowed");
    }
    
    /**
     * @notice Override approve to disable approvals
     */
    function approve(address, uint256) public pure override returns (bool) {
        revert("DebtToken: Approval not allowed");
    }
    
    /**
     * @notice Get scaled balance (balance at current index)
     * @param user User address
     * @return Scaled balance representing debt
     */
    function scaledBalanceOf(address user) external view returns (uint256) {
        return balanceOf(user);
    }
    
    /**
     * @notice Get principal balance (original borrowed amount without interest)
     * @param user User address
     * @return Principal balance
     */
    function principalBalanceOf(address user) external view returns (uint256) {
        // In a full implementation, this would track the original principal
        return balanceOf(user);
    }
}
