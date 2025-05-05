// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

    using Address for address payable;

contract DuelNFT is ERC721Enumerable, Ownable {
    uint256 public tokenIdCounter;
    mapping(uint256 => uint256) public cooldownEndTimestamp;
    mapping(uint256 => uint256) public tokenRarity;

    // ============ RARITY LOGIC ============

    struct Rarity {
        string name;
        uint256 weight;
    }
    Rarity[] public rarities;
    uint256 public totalWeight;

    event RarityAdded(uint256 indexed id, string name, uint256 weight);
    event RarityUpdated(uint256 indexed id, string name, uint256 weight);

    // ============ MINT PRICING ============

    /// @notice cost to mint in ETH
    uint256 public constant MINT_PRICE_ETH = 0.5 ether;
    /// @notice cost to mint in USDT (assumes USDT has 6 decimals)
    uint256 public constant MINT_PRICE_USDT = 1_000 * 10**18;

    IERC20 public immutable usdtToken;

    // ============ EVENTS ============

    event Minted(address indexed minter, uint256 indexed tokenId, string rarity, bool paidInETH);

    constructor(address _usdtToken)
    ERC721("Predictive Duel NFT", "PDNFT")
    Ownable(msg.sender)
    {
        usdtToken = IERC20(_usdtToken);

        // seed the 4 base rarities
        _addRarity("Common",    7_000);
        _addRarity("Rare",      2_000);
        _addRarity("Epic",        800);
        _addRarity("Legendary",   200);
        _addRarity("Mythic",   100);
    }

    /// @dev internal helper to register a new rarity
    function _addRarity(string memory name, uint256 weight) internal {
        rarities.push(Rarity(name, weight));
        totalWeight += weight;
        emit RarityAdded(rarities.length - 1, name, weight);
    }

    /// @notice add a new rarity class
    function addRarity(string calldata name, uint256 weight) external onlyOwner {
        _addRarity(name, weight);
    }

    /// @notice tweak an existing rarity
    function updateRarity(uint256 id, string calldata name, uint256 weight) external onlyOwner {
        require(id < rarities.length, "Invalid rarity ID");
        totalWeight = totalWeight - rarities[id].weight + weight;
        rarities[id].name   = name;
        rarities[id].weight = weight;
        emit RarityUpdated(id, name, weight);
    }

    // ============ MINT FUNCTIONS ============

    /// @notice Mint by paying 0.5 ETH
    function mintWithETH() external payable {
        require(msg.value == MINT_PRICE_ETH, "Incorrect ETH amount");
        _performMint(msg.sender, true);
    }

    /// @notice Mint by paying 1000 USDT
    function mintWithUSDT() external {
        require(
            usdtToken.transferFrom(msg.sender, address(this), MINT_PRICE_USDT),
            "USDT payment failed"
        );
        _performMint(msg.sender, false);
    }

    /// @dev shared mint logic
    function _performMint(address to, bool paidInETH) internal {
        uint256 tokenId = ++tokenIdCounter;
        _safeMint(to, tokenId);

        // assign rarity
        uint256 r = _pseudoRandom(tokenId, to) % totalWeight;
        uint256 bucket;
        for (uint i = 0; i < rarities.length; i++) {
            bucket += rarities[i].weight;
            if (r < bucket) {
                tokenRarity[tokenId] = i;
                break;
            }
        }

        emit Minted(to, tokenId, rarities[tokenRarity[tokenId]].name, paidInETH);
    }

    /// @dev very basic on-chain randomness (replace with VRF for production)
    function _pseudoRandom(uint256 tokenId, address minter) internal view returns (uint256) {
        return uint256(
            keccak256(abi.encodePacked(
                block.timestamp,
                block.prevrandao,     // <- use this instead of block.difficulty
                tokenId,
                minter
                ))
            );
    }

    // ============ COOLDOWN ============

    function isOnCooldown(uint256 tokenId) public view returns (bool) {
        return block.timestamp < cooldownEndTimestamp[tokenId];
    }

    function setCooldown(uint256 tokenId) external onlyOwner {
        cooldownEndTimestamp[tokenId] = block.timestamp + 16 hours;
    }

    // ============ OWNER WITHDRAWALS ============

    /// @notice Withdraw collected ETH
    function withdrawETH(address payable to) external onlyOwner {
        to.sendValue(address(this).balance);
    }

    /// @notice Withdraw collected USDT
    function withdrawUSDT(address to) external onlyOwner {
        uint256 bal = usdtToken.balanceOf(address(this));
        usdtToken.transfer(to, bal);
    }

    // ============ VIEW HELPERS ============

    function getRarityName(uint256 tokenId) external view returns (string memory) {
        return rarities[tokenRarity[tokenId]].name;
    }
}
