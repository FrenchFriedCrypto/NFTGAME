// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DuelNFT.sol";
import "./GameToken.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract PredictiveDuel is VRFConsumerBaseV2 {
    enum Turn { Player, Contract }
    enum Prediction { Above, Below }

    struct Duel {
        address player;
        uint256 nftId;
        uint256 midpoint;
        Prediction prediction;
        Turn currentTurn;
        bool active;
    }

    uint256 public duelIdCounter;
    mapping(uint256 => Duel) public duels;
    mapping(uint256 => uint256) public requestIdToDuel;

    DuelNFT public duelNFT;
    GameToken public gameToken;
    VRFCoordinatorV2Interface public coordinator;
    bytes32 public keyHash;
    uint64 public subscriptionId;
    uint32 public callbackGasLimit = 100000;

    constructor(
        address _nft,
        address _token,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        duelNFT = DuelNFT(_nft);
        gameToken = GameToken(_token);
        coordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subId;
    }

    function startDuel(uint256 nftId, uint256 midpoint, Prediction prediction) external {
        require(midpoint >= 1 && midpoint <= 999, "Midpoint out of bounds");
        require(duelNFT.ownerOf(nftId) == msg.sender, "Not NFT owner");
        require(!duelNFT.isOnCooldown(nftId), "NFT on cooldown");

        uint256 duelId = ++duelIdCounter;
        duels[duelId] = Duel(msg.sender, nftId, midpoint, prediction, Turn.Player, true);
        uint256 requestId = coordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            3,                // min confirmations
            callbackGasLimit,
            1                 // numWords
        );
        requestIdToDuel[requestId] = duelId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 duelId = requestIdToDuel[requestId];
        Duel storage duel = duels[duelId];
        require(duel.active, "Duel not active");

        uint256 rng = (randomWords[0] % 1000) + 1;

        if (duel.currentTurn == Turn.Player) {
            bool won = (duel.prediction == Prediction.Above && rng > duel.midpoint) ||
                (duel.prediction == Prediction.Below && rng < duel.midpoint);
            if (won) {
                duel.currentTurn = Turn.Contract;
                contractTurn(duelId);
            } else {
                duel.active = false;
                duelNFT.setCooldown(duel.nftId);
            }
        }
    }

    function contractTurn(uint256 duelId) internal {
        Duel storage duel = duels[duelId];
        uint256 midpoint = 1 + (uint256(keccak256(abi.encodePacked(block.timestamp, duelId))) % 999);
        Prediction prediction = Prediction(uint256(keccak256(abi.encodePacked(msg.sender, duelId))) % 2);

        uint256 requestId = coordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            3,
            callbackGasLimit,
            1
        );
        requestIdToDuel[requestId] = duelId;

        // Replace Duel state with contract's prediction if needed
        duel.midpoint = midpoint;
        duel.prediction = prediction;
        duel.currentTurn = Turn.Contract;
    }

    function rewardPlayer(uint256 duelId) internal {
        Duel storage duel = duels[duelId];
        uint256 reward = calculateReward(duel.midpoint) * 1e18;
        gameToken.mint(duel.player, reward);
    }

    function calculateReward(uint256 midpoint) public pure returns (uint256) {
        uint256 distance = midpoint > 500 ? midpoint - 500 : 500 - midpoint;
        return 100 + (400 - distance * 8 / 10); // result in basis points
    }
}
