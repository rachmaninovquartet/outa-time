const { expect } = require("chai");
//const { BigNumber } = require("ethers");

describe("Phase 1", function () {
  it("Add users to WL", async function () {
    const [owner] = await ethers.getSigners();

    const NFT = await ethers.getContractFactory("ERC721Collection");
        /*
        string memory name,
        string memory symbol,
        uint256 price,
        uint256 maxTotalMint,
        uint256 maxPreSaleMintPerAddress,
        uint256 maxMintPerTransaction,
        uint256 maxAllowedGasFee,
        string memory contractURI,
        string memory placeholderURI,
        address raribleRoyaltyAddress, //TODO
        address openSeaProxyRegistryAddress //TODO
        */

    const hhNFT = await NFT.deploy("TIME", "TIME",  ethers.utils.parseUnits('0.24', 'ether'), 2400, 3, 0, "abc", "def", "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D");
    const ownerBalance = await hhNFT.addToTier([owner.address], 1);
    expect(await hhNFT.onTier1List(owner.address)).to.equal(true);
    expect(await hhNFT.onTier2List(owner.address)).to.equal(false);
    console.log("K")

    //rarity
    console.log(await hhNFT.testRarity());

    //await expect(hhNFT.mint(owner.address, 3)).to.be.reverted;
    //await hhNFT.togglePreSale(true); //TODO other toggles
    //const owner_minted = await hhNFT.mint(owner.address, 3); //TODO test 4

    expect(await hhNFT.totalSupply()).to.equal(0);
    expect(await hhNFT.auctionSupplyRemaining()).to.equal(0);
    hhNFT.startDutchAuction(ethers.utils.parseUnits('0.24', 'ether'), ethers.utils.parseUnits('0.02', 'ether'), 2400)
    expect(await hhNFT.auctionSupplyRemaining()).to.equal(2400);
    console.log();
    await network.provider.send("evm_setNextBlockTimestamp", [1691590822])
    await network.provider.send("evm_mine")
    console.log(await hhNFT.getBlocktime());
    await network.provider.send("evm_increaseTime", [3600])
    await network.provider.send("evm_mine")
    console.log(await hhNFT.getBlocktime());
    expect(await hhNFT.getBlocktime()).to.equal(1691590822 + 3600);
  });
});
