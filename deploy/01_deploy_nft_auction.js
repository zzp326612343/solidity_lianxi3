const { deployments,upgrades,ethers } = require("hardhat");

const fs = require('fs');
const path = require('path');

module.exports = async ({ deployments, getNamedAccounts }) => { 
    const { save } = deployments;
    const { deployer } = await getNamedAccounts();
    console.log("部署用户地址：", deployer);
    const NFTAuction = await ethers.getContractFactory("NftAuction");
    const nftAuction = await upgrades.deployProxy(NFTAuction, [], { initializer: "initialize" });
    await nftAuction.waitForDeployment();
    const proxyAddress = await nftAuction.getAddress();
    const implAddress  = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    const storePath = path.resolve(__dirname, '../deployments/nft_auction.json');
    fs.writeFileSync(storePath, JSON.stringify({
        proxyAddress,
        implAddress,
        abi: NFTAuction.interface.format('json'),
    }));

    await save("NftAuctionProxy", {
        address: proxyAddress,
        abi: NFTAuction.interface.format('json'),
    });
};

module.exports.tags = ["deployNftAuction"];