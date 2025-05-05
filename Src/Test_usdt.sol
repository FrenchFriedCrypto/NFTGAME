// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {

    uint256 public constant INITIAL_SUPPLY = 10000_000 * (10 ** 18);

    constructor()
        ERC20("Tewa", "TEW")
        Ownable(msg.sender)      // pass deployer as initial owner
    {
        // Mint 500 000 whole tokens (500000 * 10^decimals) to deployer
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /// @notice Override decimals—18 by default for ERC20
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /// @notice Owner can mint additional tokens as needed
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
