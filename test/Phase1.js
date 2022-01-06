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

    const hhNFT = await NFT.deploy("TIME", "TIME",  ethers.utils.parseUnits('0.24', 'ether'), 2400, 3, 3, 0, "abc", "def", "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D");
    const ownerBalance = await hhNFT.addToPreSaleAllowList([owner.address]);
    expect(await hhNFT.onPreSaleAllowList(owner.address)).to.equal(true);
    await expect(hhNFT.mint(owner.address, 3)).to.be.reverted;
    await hhNFT.togglePreSale(true);
    const owner_minted = await hhNFT.mint(owner.address, 3); //TODO test 4
    console.log();
    expect(await hhNFT.totalSupply()).to.equal(3);
  });
});
