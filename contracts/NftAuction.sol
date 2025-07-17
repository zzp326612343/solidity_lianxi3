// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NftAuction is Initializable, UUPSUpgradeable {

    struct Auction {
        // 卖家
        address seller;
        // 拍卖持续时间
        uint256 duration;
        // 起始价格
        uint256 startPrice;
        // 开始时间
        uint256 startTime;
        // 是否结束
        bool ended;
        // 最高出价者
        address highestBidder;
        // 最高价格
        uint256 highestBid;
        // NFT合约地址
        address nftContract;
        // NFT ID
        uint256 tokenId;
        // 参与竞价的资产类型 0x 地址表示eth，其他地址表示erc20
        // 0x0000000000000000000000000000000000000000 表示eth
        address tokenAddress;
    }

    mapping(uint256 => Auction) public auctions;

    uint256 public nextAutionId;

    address public admin;

    mapping(address => AggregatorV3Interface) public priceFeeds;

    function initialize() public initializer {
        admin = msg.sender;
    }

    function setPriceFeed(
        address tokenAddress,
        address _priceFeed
    ) public {
        priceFeeds[tokenAddress] = AggregatorV3Interface(_priceFeed);
    }

    // ETH -> USD => 1766 7512 1800 => 1766.75121800
    // USDC -> USD => 9999 4000 => 0.99994000
    function getChainlinkDataFeedLatestAnswer(
        address tokenAddress
    ) public view returns (int) {
        AggregatorV3Interface priceFeed = priceFeeds[tokenAddress];
        // prettier-ignore
        (
            /* uint80 roundId */,
            int256 answer,
            /*uint256 startedAt*/,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return answer;
    }

    // 创建拍卖
    function createAuction(
        uint256 _duration,
        uint256 _startPrice,
        address _nftAddress,
        uint256 _tokenId
    ) public {
        require(_duration > 0, "duration must be greater than 0");
        require(_startPrice > 0, "startPrice must be greater than 0");
        require(_nftAddress != address(0), "nftAddress can not be 0");
        IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
        auctions[nextAutionId] = Auction(
            {
                seller: msg.sender,
                duration: _duration,
                startPrice: _startPrice,
                ended: false,
                highestBidder: address(0),
                highestBid: 0,
                startTime: block.timestamp,
                nftContract: _nftAddress,
                tokenId: _tokenId,
                tokenAddress: address(0)
            }
        );
        nextAutionId++;
    }

    function placeBid(
        uint256 _auctionID,
        uint256 amount,
        address _tokenAddress
    ) external payable {
        Auction storage auction = auctions[_auctionID];
        require(
            (auction.startTime + auction.duration) >
                block.timestamp && !auction.ended,
            "Auction has ended"
        );
        
        uint payValue;
        if (_tokenAddress == address(0)) {
            // 处理 ETH
            amount = msg.value;
            payValue = amount * uint(getChainlinkDataFeedLatestAnswer(address(0)));
        } else {
            payValue = amount * uint(getChainlinkDataFeedLatestAnswer(_tokenAddress));
        }
        uint startPriceValue = auction.startPrice *
            uint(getChainlinkDataFeedLatestAnswer(auction.tokenAddress));

        uint highestBidValue = auction.highestBid *
            uint(getChainlinkDataFeedLatestAnswer(auction.tokenAddress));
        require(payValue >= startPriceValue && payValue > highestBidValue,"Bid must be higher than the current highest bid");
          // 转移 ERC20 到合约
        if (_tokenAddress != address(0)) {
            IERC20(_tokenAddress).transferFrom(msg.sender, address(this), amount);
        }
        // 退还前最高价
        if (auction.highestBid > 0) {
            if (auction.tokenAddress == address(0)) {
                // auction.tokenAddress = _tokenAddress;
                payable(auction.highestBidder).transfer(auction.highestBid);
            } else {
                // 退回之前的ERC20
                IERC20(auction.tokenAddress).transfer(
                    auction.highestBidder,
                    auction.highestBid
                );
            }
        }
        
        auction.highestBid = amount;
        auction.highestBidder = msg.sender;
        auction.tokenAddress = _tokenAddress;
    }

    // 结束拍卖
    function endAuction(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];
        require(!auction.ended && (auction.startTime + auction.duration) <= block.timestamp, "Auction not ended yet");
        IERC721(auction.nftContract).safeTransferFrom(address(this), auction.highestBidder, auction.tokenId);
        if (auction.tokenAddress == address(0)) {
            payable(auction.seller).transfer(auction.highestBid);
        } else {
            IERC20(auction.tokenAddress).transfer(auction.seller, auction.highestBid);
        }
        auction.ended = true;
    }

    function _authorizeUpgrade(address) internal view override {
        // 只有管理员可以升级合约
        require(msg.sender == admin, "Only admin can upgrade");
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}