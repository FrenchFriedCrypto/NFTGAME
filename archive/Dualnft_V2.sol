Dualnft_V1.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";           // drop Enumerable if you don't need on‐chain enumeration
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract DuelNFT is ERC721, Ownable {

    using Address for address payable;

    uint256 public tokenIdCounter;
    mapping(uint256 => uint256) public cooldownEndTimestamp;
    mapping(uint256 => uint256) public tokenRarity;

    struct Rarity {
        string name;
        uint256 weight;
        string uri;         // ← an IPFS URI (e.g. "ipfs://Qm…/common.json")
    }
    Rarity[] public rarities;
    uint256 public totalWeight;

    IERC20 public immutable usdtToken;



    // ============ MINT PRICING ============

    /// @notice cost to mint in ETH
    uint256 public constant MINT_PRICE_ETH = 0.5 ether;
    /// @notice cost to mint in USDT (assumes USDT has 6 decimals)
    uint256 public constant MINT_PRICE_USDT = 1_000 * 10**18;



    event Minted(address indexed minter, uint256 indexed tokenId, string rarity, bool paidInETH);
    event RarityAdded(uint256 indexed id, string name, uint256 weight, string uri);
    event RarityUpdated(uint256 indexed id, string name, uint256 weight, string uri);

    constructor(address _usdtToken) ERC721("Predictive Duel NFT", "PDNFT") Ownable(msg.sender){
        usdtToken = IERC20(_usdtToken);

        // seed rarities with their IPFS metadata pointers
        _addRarity("Common",    7_000, "ipfs://bafybeiatnogjmc6rcni422ydipr6r4jkrgkuhoo26ccqjbfa5on47p24dq");
        _addRarity("Rare",      2_000, "ipfs://bafybeihkkhcdjzebx2noynyhzykrjfygfope4gvdp3mow73cne6sje4n5y");
        _addRarity("Epic",        800, "ipfs://bafybeidgekdihj525qqrvdr4xwq6yixhdh4p44edl5py2ajlfiaydexvbe");
        _addRarity("Legendary",   200, "ipfs://bafybeigbpfguia5hnxs4kqm2hyiy5grqex55zdjog4ootoaf2gq34ru3j4");
        _addRarity("Mythic",   1_000, "ipfs://bafybeidbgmo2iiw2f3xqkr4ecl6id45lyjwdvqguxd2t75kjt34vluuomu");
    }

    function _addRarity(string memory name, uint256 weight, string memory uri) internal {
        rarities.push(Rarity(name, weight, uri));
        totalWeight += weight;
        emit RarityAdded(rarities.length - 1, name, weight, uri);
    }

    /// @notice owner can add new rarity classes (with their own IPFS URI)
    function addRarity(string calldata name, uint256 weight, string calldata uri) external onlyOwner {
        _addRarity(name, weight, uri);
    }

    /// @notice tweak an existing rarity (including its metadata pointer)
    function updateRarity(
        uint256 id,
        string calldata name,
        uint256 weight,
        string calldata uri
    ) external onlyOwner {
        require(id < rarities.length, "Invalid rarity ID");
        totalWeight = totalWeight - rarities[id].weight + weight;
        rarities[id].name   = name;
        rarities[id].weight = weight;
        rarities[id].uri    = uri;
        emit RarityUpdated(id, name, weight, uri);
    }

    // … your mintWithETH / mintWithUSDT / _performMint / randomness / cooldown / withdrawal logic …


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

    /// @dev returns the metadata URI for a token based on its assigned rarity
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "ERC721Metadata: nonexistent token");
        return rarities[tokenRarity[tokenId]].uri;
    }
}
