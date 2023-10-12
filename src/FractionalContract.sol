// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract FractionalContract is ERC1155 {
    uint256 public _tokenIds;

    uint256 public platformFee = 1; // 0.1%

    // Mapping to store the token shares owned by each address.
    mapping(uint256 => mapping(address => uint256)) public sharesBalances;

    // Mapping to store the total supply of each token ID
    mapping(uint256 => uint256) public tokenTotalSupply;

    // Mapping to store the owner of each token ID
    mapping(uint256 => address) public tokenOwners;

    event SharesPurchased(
        address indexed buyer,
        uint256 tokenId,
        uint256 amount,
        uint256 cost
    );
    event SharesTransferred(
        address indexed from,
        address indexed to,
        uint256 tokenId,
        uint256 amount
    );
    event Minted(uint256 tokenId, string uri);

    constructor(string memory uri) ERC1155(uri) {
        // Initialize your contract with a base URI
    }

    function mintNFT(string memory tokenURI) external {
        _tokenIds++;
        uint256 tokenId = _tokenIds;
        _mint(msg.sender, tokenId, 1, "");
        sharesBalances[tokenId][msg.sender] = 10000; // 100% shares to the owner
        tokenOwners[tokenId] = msg.sender;
        emit Minted(tokenId, tokenURI);
    }

    function purchaseShares(uint256 tokenId, uint256 amount) external payable {
        uint256 cost = calculateCost(tokenId, amount);
        require(msg.value >= cost, "Insufficient payment");

        uint256 platformFeeAmount = (cost * platformFee) / 10000;
        uint256 ownerAmount = cost - platformFeeAmount;

        address payable owner = payable(tokenOwners[tokenId]);

        sharesBalances[tokenId][owner] -= amount;
        sharesBalances[tokenId][msg.sender] += amount;

        owner.transfer(ownerAmount);
        payable(owner).transfer(platformFeeAmount);

        emit SharesPurchased(msg.sender, tokenId, amount, cost);
    }

    function transferShares(
        uint256 tokenId,
        address to,
        uint256 amount
    ) external {
        require(
            sharesBalances[tokenId][msg.sender] >= amount,
            "Insufficient shares"
        );
        sharesBalances[tokenId][msg.sender] -= amount;
        sharesBalances[tokenId][to] += amount;
        emit SharesTransferred(msg.sender, to, tokenId, amount);
    }

    function calculateCost(
        uint256 tokenId,
        uint256 amount
    ) public view returns (uint256) {
        uint256 sharesPrice = calculateSharesPrice(tokenId);
        return sharesPrice * amount;
    }

    function calculateSharesPrice(
        uint256 tokenId
    ) public view returns (uint256) {
        return
            (tokenTotalSupply[tokenId] * 1 ether) /
            sharesBalances[tokenId][address(this)];
    }
}
