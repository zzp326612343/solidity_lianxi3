// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NftAuction.sol";

contract NftAuctionFactory {

    address[] public auctions;
    mapping(uint256 => NftAuction) public auctionMap;
    event AuctionCreated(address indexed auctionAddress, uint256 tokenId);

    function createAuction(
        uint256 _duration,
        uint256 _startPrice,
        address _nftAddress,
        uint256 _tokenId
    ) external returns (address) {
        NftAuction auction = new NftAuction();
        auction.initialize();
        // auction.createAuction(_duration, _startPrice, _nftAddress, _tokenId);
        auctions.push(address(auction));
        auctionMap[_tokenId] = auction;
        emit AuctionCreated(address(auction), _tokenId);
    }
    function getAuctions() external view returns (address[] memory) {
        return auctions;
    }

    function getAuction(uint256 tokenId) external view returns (address) {
        require(tokenId < auctions.length, "tokenId out of bounds");
        return auctions[tokenId];
    }
}