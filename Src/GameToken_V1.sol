// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Predictive Token (PDT) with a hard cap and owner minting
contract GameToken is ERC20, Ownable {
    /// @dev 100 million tokens, accounting for 18 decimals
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** 18;

    /// @notice Address of your game contract allowed to mint
    address public gameContract;

    /// @param initialSupply Optional number of tokens to mint to deployer at construction
    constructor(uint256 initialSupply)
    ERC20("Predictive Token", "PDT")
    Ownable(msg.sender)
    {
        require(initialSupply <= MAX_SUPPLY, "Initial supply exceeds cap");
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }

    /// @notice Set the game contract that’s allowed to mint PDT
    function setGameContract(address _game) external onlyOwner {
        gameContract = _game;
    }

    /// @notice Mint tokens when a game win occurs (only your game contract)
    function mint(address to, uint256 amount) external {
        require(msg.sender == gameContract, "Only game contract can mint");
        _mintWithCap(to, amount);
    }

    /// @notice Owner can mint at any time (e.g. for rewards, liquidity, etc.)
    function ownerMint(address to, uint256 amount) external onlyOwner {
        _mintWithCap(to, amount);
    }

    /// @dev Internal minting helper enforcing the cap
    function _mintWithCap(address to, uint256 amount) internal {
        require(totalSupply() + amount <= MAX_SUPPLY, "Cap exceeded");
        _mint(to, amount);
    }
}
