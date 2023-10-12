// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./FractionalContract.sol";

contract NFTMarketplace {
    struct Listing {
        uint256 tokenId;
        uint256 price;
        uint256 numberOfShares;
        address seller;
    }

    FractionalContract public fractionalContract; // Reference to the Fraktal1155 contract

    // STORAGE
    mapping(uint256 => Listing) public listings;
    uint256 public fee;
    // EVENTS
    event FeeUpdated(uint256 newFee);
    event ItemListed(uint256 tokenId, uint256 price, uint256 amountOfShares);
    event ItemPriceUpdated(uint256 tokenId, uint256 newPrice);
    event ItemPurchased(
        uint256 tokenId,
        address indexed buyer,
        uint256 sharesPurchased,
        uint256 totalCost
    );
    event ItemUnlisted(uint256 tokenId);

    constructor(address _fractionalContractAddress) {
        fractionalContract = FractionalContract(_fractionalContractAddress);
        fee = 0; // Initialize the fee to 0
    }

    function setFee(uint256 _newFee) external {
        require(_newFee >= 0, "NFTMarketplace: Negative fee not acceptable");
        fee = _newFee;
        emit FeeUpdated(_newFee);
    }

    // List an NFT with its ID, price, and number of shares.
    function listNFT(
        uint256 _tokenId,
        uint256 _price,
        uint256 _numberOfShares
    ) external {
        require(_price > 0, "NFTMarketplace: Price must be greater than zero");
        require(
            _numberOfShares > 0,
            "NFTMarketplace: Number of shares must be greater than zero"
        );
        require(
            fractionalContract.tokenOwners(_tokenId) == address(this),
            "NFTMarketplace: Contract does not own the NFT"
        );

        Listing storage listing = listings[_tokenId];
        listing.tokenId = _tokenId;
        listing.price = _price;
        listing.numberOfShares = _numberOfShares;
        listing.seller = msg.sender;

        emit ItemListed(_tokenId, _price, _numberOfShares);
    }

    // Update the price of an existing listing.
    function updatePrice(uint256 _tokenId, uint256 _newPrice) external {
        require(
            _newPrice > 0,
            "NFTMarketplace: Price must be greater than zero"
        );
        Listing storage listing = listings[_tokenId];
        require(listing.tokenId != 0, "NFTMarketplace: Invalid token id");
        listing.price = _newPrice;
        emit ItemPriceUpdated(_tokenId, _newPrice);
    }

    // Purchase shares of an NFT from the marketplace.
    function purchaseShares(
        uint256 _tokenId,
        uint256 _sharesToPurchase
    ) external payable {
        Listing storage listing = listings[_tokenId];
        require(listing.tokenId != 0, "NFTMarketplace: Invalid token id");
        require(
            _sharesToPurchase > 0,
            "NFTMarketplace: Number of shares to purchase must be greater than zero"
        );
        require(
            listing.numberOfShares >= _sharesToPurchase,
            "NFTMarketplace: Requested shares amount exceeds balance"
        );
        uint256 totalPrice = listing.price * _sharesToPurchase;
        require(msg.value >= totalPrice, "NFTMarketplace: Insufficient funds");

        // Calculate fees
        uint256 platformFeeAmount = (totalPrice * fee) / 10000; // fee is in percentage
        uint256 sellerAmount = totalPrice - platformFeeAmount;

        // Transfer shares to the buyer
        fractionalContract.safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            _sharesToPurchase,
            ""
        );

        // Transfer funds to the seller and platform
        payable(listing.seller).transfer(platformFeeAmount);
        payable(fractionalContract.tokenOwners(_tokenId)).transfer(
            sellerAmount
        );

        // Update the number of shares available in the listing
        listing.numberOfShares = listing.numberOfShares - _sharesToPurchase;

        emit ItemPurchased(_tokenId, msg.sender, _sharesToPurchase, totalPrice);
    }

    // Unlist an NFT from the marketplace.
    function unlistNFT(uint256 _tokenId) external {
        Listing storage listing = listings[_tokenId];
        require(listing.tokenId != 0, "NFTMarketplace: Invalid token id");
        delete listings[_tokenId];
        emit ItemUnlisted(_tokenId);
    }
}
