// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.9;
//TODO turn on solidity optimizer in hardhat.config prior to deploy
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

//import "./opensea/ProxyRegistry.sol"; //TODO is needed
//import "./rarible/IRoyalties.sol";
//import "./rarible/LibPart.sol";
import "./rarible/LibRoyaltiesV2.sol";

// TODO Add contract check by Size AND (tx.origin == msg.sender)
contract ERC721Collection is ERC721, Ownable, ReentrancyGuard, AccessControl {//, IRoyalties {
    using SafeMath for uint256;
    using Address for address;
    using Address for address payable;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public PRICE;
    uint256 public MAX_TOTAL_MINT;

    // Fair distribution, thundering-herd mitigation and gas-wars prevention
    //uint256 public MAX_PRE_SALE_MINT_PER_ADDRESS;
    //uint256 public MAX_MINT_PER_TRANSACTION;
    uint8 public MAX_PER_ADDRESS;
    uint256 public MAX_ALLOWED_GAS_FEE;

    bool private _isTier1WLActive;
    bool private _isTier2WLActive;
    bool private _isTier3WLActive;

    //bool private _isPreSaleActive;
    bool private _isPublicSaleActive;
    //bool private _isPurchaseEnabled;
    string private _contractURI;
    string private _placeholderURI;
    string private _baseTokenURI;
    bool private _baseURIFrozen;
    address private _raribleRoyaltyAddress;
    address private _openSeaProxyRegistryAddress;

    uint256 private _currentTokenId = 0;

    //mapping(address => bool) private _preSaleAllowList;
    mapping(address => bool) private _tier1AllowList;
    mapping(address => bool) private _tier2AllowList;
    mapping(address => bool) private _tier3AllowList;
    mapping(address => uint8) private _totalClaimed; //TODO reset per auction?
    //mapping(address => uint256) private _preSaleAllowListClaimed;

    constructor( //TODO less work in constructor
        string memory name,
        string memory symbol,
        uint256 price, //TODO is handled in dutch auction
        uint256 maxTotalMint,
        uint8 maxPerAddress, //TODO convert all 256 to 8 that can be
        //uint256 maxPreSaleMintPerAddress,
        //uint256 maxMintPerTransaction,
        uint256 maxAllowedGasFee,
        string memory contractURI,
        string memory placeholderURI,
        address raribleRoyaltyAddress,
        address openSeaProxyRegistryAddress
    ) ERC721(name, symbol) {
        PRICE = price;
        MAX_TOTAL_MINT = maxTotalMint;
        MAX_PER_ADDRESS = maxPerAddress;
        //MAX_PRE_SALE_MINT_PER_ADDRESS = maxPreSaleMintPerAddress;
        //MAX_MINT_PER_TRANSACTION = maxMintPerTransaction;
        MAX_ALLOWED_GAS_FEE = maxAllowedGasFee;

        _contractURI = contractURI;
        _placeholderURI = placeholderURI;
        _raribleRoyaltyAddress = raribleRoyaltyAddress;
        _openSeaProxyRegistryAddress = openSeaProxyRegistryAddress;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());

        //_initializeEIP712(name); TODO from polygon
    }

    // ADMIN

    function togglePublicSale(bool isActive) external onlyOwner {
        _isPublicSaleActive = isActive;
    }

    /*
    function togglePreSale(bool isActive) external onlyOwner {
        _isPreSaleActive = isActive;
    }
*/
    /*
    function togglePurchaseEnabled(bool isActive) external onlyOwner {
        _isPurchaseEnabled = isActive;
    }
    */

    function setBaseURI(string memory baseURI) external onlyOwner {
        require(!_baseURIFrozen, "ERC721/BASE_URI_FROZEN");
        _baseTokenURI = baseURI;
    }

    function freezeBaseURI() external onlyOwner {
        _baseURIFrozen = true;
    }

    function setPlaceholderURI(string memory placeholderURI) external onlyOwner {
        _placeholderURI = placeholderURI;
    }

    function setContractURI(string memory uri) external onlyOwner {
        _contractURI = uri;
    }

    function setMaxAllowedGasFee(uint256 maxFeeGwei) external onlyOwner {
        MAX_ALLOWED_GAS_FEE = maxFeeGwei;
    }
//todo remove
    function setRaribleRoyaltyAddress(address addr) external onlyOwner {
        _raribleRoyaltyAddress = addr;
    }
//todo ?
    function setOpenSeaProxyRegistryAddress(address addr) external onlyOwner {
        _openSeaProxyRegistryAddress = addr;
    }

    function withdraw() external onlyOwner { //TODO do we want https://gnosis-safe.io/
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // PUBLIC

    function totalSupply() public view returns (uint256) {
        return _currentTokenId;
    }

    function auctionSupplyRemaining() public view returns (uint256) {
        return _totalPerAuction;
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 _tokenId) override public view returns (string memory) {
        return bytes(_baseTokenURI).length > 0 ? string(abi.encodePacked(_baseTokenURI, Strings.toString(_tokenId))) : _placeholderURI;
    }

    //TODO don't need royalties?
    /*
    function getRaribleV2Royalties(uint256 id) override external view returns (LibPart.Part[] memory result) {
        result = new LibPart.Part[](1);

        result[0].account = payable(_raribleRoyaltyAddress);
        result[0].value = 10000;
        // 100% of royalty goes to defined address above.
        id;
        // avoid unused param warning
    }
    */

    function getInfo() external view returns (
        uint256 price,
        uint256 totalSupply,
        uint256 senderBalance,
        uint256 totalClaimed,
        uint256 maxTotalMint,
        uint256 maxPreSaleMintPerAddress,
        //uint256 maxMintPerTransaction,
        uint256 maxAllowedGasFee,
        //bool isPreSaleActive,
        bool isPublicSaleActive
        //bool isPurchaseEnabled,
        //bool isSenderAllowlisted
    ) {
        return (
        PRICE,
        this.totalSupply(),
        msg.sender == address(0) ? 0 : this.balanceOf(msg.sender),
        //_preSaleAllowListClaimed[msg.sender],
        _totalClaimed[msg.sender],
        MAX_TOTAL_MINT,
        MAX_PER_ADDRESS,
        //MAX_MINT_PER_TRANSACTION,
        MAX_ALLOWED_GAS_FEE,
        //_isPreSaleActive,
        _isPublicSaleActive
        //_isPurchaseEnabled,
        //_preSaleAllowList[msg.sender]
        );
    }
/*
    //TODO royalties
    /**
     * @dev See {IERC165-supportsInterface}.
     */

    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721, AccessControl)
    returns (bool)
    {
        if (interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }


    /**
     * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    /* TODO prbably want this
    function isApprovedForAll(address owner, address operator)
    override
    public
    view
    returns (bool)
    {
        if (_openSeaProxyRegistryAddress != address(0)) {
            if (block.chainid == 1 || block.chainid == 4 || block.chainid == 5) { //TODO don't need this check
                // Whitelist OpenSea proxy contract for easy trading.
                ProxyRegistry proxyRegistry = ProxyRegistry(_openSeaProxyRegistryAddress);
                if (address(proxyRegistry.proxies(owner)) == operator) {
                    return true;
                }
            }
        }

        return super.isApprovedForAll(owner, operator);
    }
*/
    function addToTier(address[] calldata addresses, int8 tier) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Can't add the null address");
            if (tier == 1) {
                _tier1AllowList[addresses[i]] = true;
            } else if (tier == 2) {
                _tier2AllowList[addresses[i]] = true;
            } else {
                _tier3AllowList[addresses[i]] = true;
            }
        }
    }

    function addToPreSaleTiers(address[] calldata addresses1, address[] calldata addresses2, address[] calldata addresses3) external onlyOwner {
        addToTier(addresses1, 1);
        addToTier(addresses2, 2);
        addToTier(addresses3, 3);
    }

    function onTier1List(address addr) external view returns (bool) {
        return _tier1AllowList[addr];
    }

    function onTier2List(address addr) external view returns (bool) {
        return _tier2AllowList[addr];
    }

    function onTier3List(address addr) external view returns (bool) {
        return _tier3AllowList[addr];
    }

    /** TODO remove or could be useful, needed for influencers
     * Mints a specified number of tokens to an address without requiring payment.
     * Caller must be an address with MINTER role.
     *
     * Useful for gifting by owner or integration with Flair.Finance funding options.
     */
    /*
    function mint(address to, uint256 count) public nonReentrant {
        // Only allow minters to bypass the payment
        require(hasRole(MINTER_ROLE, msg.sender), "ERC721_COLLECTION/NOT_MINTER_ROLE");

        // Make sure minting is allowed
        requireMintingConditions(to, count);

        if (_isPreSaleActive && !_isPublicSaleActive) {
            _preSaleAllowListClaimed[to] += count;
        }

        for (uint256 i = 0; i < count; i++) {
            uint256 newTokenId = _getNextTokenId();
            _safeMint(to, newTokenId);
            _incrementTokenId();
        }
    }
    */

    /**
     * Accepts required payment and mints a specified number of tokens to an address.
     * This method also checks if direct purchase is enabled.
     */
    /*
    function purchase(uint256 count) public payable nonReentrant {
        // Caller cannot be a smart contract to avoid front-running by bots
        require(!msg.sender.isContract(), 'ERC721_COLLECTION/CONTRACT_CANNOT_CALL');

        // Make sure minting is allowed
        requireMintingConditions(msg.sender, count);

        // Sent value matches required ETH amount TODO doesn't seem to do what the comment says!
        require(_isPurchaseEnabled, 'ERC721_COLLECTION/PURCHASE_DISABLED');

        // Sent value matches required ETH amount TODO dutch auction
        require(PRICE * count <= msg.value, 'ERC721_COLLECTION/INSUFFICIENT_ETH_AMOUNT');

        if (_isPreSaleActive) {
            _preSaleAllowListClaimed[msg.sender] += count;
        }

        for (uint256 i = 0; i < count; i++) {
            uint256 newTokenId = _getNextTokenId();
            _safeMint(msg.sender, newTokenId);
            _incrementTokenId();
        }
    }
*/
    /**
     * Useful for when user wants to return tokens to get a refund,
     * or when they want to transfer lots of tokens by paying gas fee only once.
     */ //TODO is needed
    /*
    function transferFromBulk(
        address from,
        address to,
        uint256[] memory tokenIds
    ) public virtual {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            //solhint-disable-next-line max-line-length
            require(_isApprovedOrOwner(_msgSender(), tokenIds[i]), "ERC721: transfer caller is not owner nor approved");
            _transfer(from, to, tokenIds[i]);
        }
    }
    */

    // PRIVATE

    /**
     * This method checks if ONE of these conditions are met:
     *   - Public sale is active.
     *   - Pre-sale is active and receiver is allowlisted.
     *
     * Additionally ALL of these conditions must be met:
     *   - Gas fee must be equal or less than maximum allowed.
     *   - Newly requested number of tokens will not exceed maximum total supply.
     */
    function requireMintingConditions(address to, uint256 count) internal view {
        require(// public sale or one of the WL sales
            _isPublicSaleActive ||
            ((_isTier1WLActive && _tier1AllowList[to]) || (_isTier2WLActive && _tier2AllowList[to]) || (_isTier3WLActive && _tier3AllowList[to])
            && _totalClaimed[to] + count <= MAX_PER_ADDRESS) //TODO total claimed is per auction or ever?
        , "ERC721_COLLECTION/CANNOT_MINT");

        // If max-gas fee is configured (avoid gas wars), transaction must not exceed that
        if (MAX_ALLOWED_GAS_FEE > 0)
            require(tx.gasprice < MAX_ALLOWED_GAS_FEE * 1000000000, "ERC721_COLLECTION/GAS_FEE_NOT_ALLOWED");

        // Total minted tokens must not exceed maximum supply TODO not needed?
        require(totalSupply() + count <= MAX_TOTAL_MINT, "ERC721_COLLECTION/EXCEEDS_MAX_SUPPLY");

        // Number of minted tokens must not exceed maximum limit per transaction
        require(count <= MAX_PER_ADDRESS, "ERC721_COLLECTION/EXCEEDS_MAX_PER_TX");
    }

    /**
     * Calculates the next token ID based on value of _currentTokenId
     * @return uint256 for the next token ID
     */
    function _getNextTokenId() private view returns (uint256) {
        return _currentTokenId.add(1);
    }

    /**
     * Increments the value of _currentTokenId
     */
    function _incrementTokenId() private {
        _currentTokenId++;
    }

    //TODO needed? (below are new methods)
    function testRarity() public view returns(uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender))) % 100;
    }

    event Buy(address winner, uint amount);
    //address payable public seller;
    uint public _startingPrice;
    uint public _startAt;
    uint public _expiresAt;
    uint public _priceDeductionRate;
    //address public winner;
    uint public _totalPerAuction;

    function startDutchAuction(uint startingPrice, uint priceDeductionRate, uint totalPerAuction) external onlyOwner {
        //seller = payable(msg.sender); //TODO probably not needed
        _startingPrice = _startingPrice;
        _startAt = block.timestamp;
        _expiresAt = block.timestamp + 6 hours;
        _priceDeductionRate = priceDeductionRate;
        //nft = IERC721(_nft);
        //nftId = _nftId;
        _totalPerAuction = totalPerAuction;
    }

    //TODO is nonreentrant
    function buyFromDutchAuction(uint8 count) external payable {
        // Caller cannot be a smart contract to avoid front-running by bots
        require(!msg.sender.isContract(), 'ERC721_COLLECTION/CONTRACT_CANNOT_CALL');
        require(block.timestamp < _expiresAt, "auction expired");
        require(_totalPerAuction > 0, "all nfts sold for this auction");

        uint timeElapsed = block.timestamp - _startAt;
        uint deduction = _priceDeductionRate * timeElapsed;
        uint price = _startingPrice - deduction;

        require(msg.value >= price, "ETH < price");

        //winner = msg.sender;
        //nft.transferFrom(seller, msg.sender, nftId);
        //seller.transfer(msg.value);
        //TODO integrate purchase
             // Make sure minting is allowed
        requireMintingConditions(msg.sender, count);

        // Sent value matches required ETH amount TODO doesn't seem to do what the comment says!
        //require(_isPurchaseEnabled, 'ERC721_COLLECTION/PURCHASE_DISABLED');

        // Sent value matches required ETH amount TODO dutch auction
        require(PRICE * count <= msg.value, 'ERC721_COLLECTION/INSUFFICIENT_ETH_AMOUNT');

        _totalClaimed[msg.sender] += count;

        for (uint256 i = 0; i < count; i++) {
            uint256 newTokenId = _getNextTokenId();
            _safeMint(msg.sender, newTokenId);
            _incrementTokenId(); //TODO how to deal with per auction supply
            _totalPerAuction--; //TODO here, in above f() or it's own f()
        }

        emit Buy(msg.sender, msg.value); //TODO multiple ids etc? metadata?
    }

    //TODO debug

    function getBlocktime() public view returns(uint256) {
        return block.timestamp;
    }

    /*
    ~ Watch hands closer to midnight = increased rarity (will do in 5 min intervals probably depending on rest of rarity split) 10:10 being the rarest of each of the below variants
~ Colour of watch hands
~ Face of watch
~ Colour of the bezel
~ Case (gold, silver, platinum etc)
~ Band (a lot of options to choose from here)
*/
}