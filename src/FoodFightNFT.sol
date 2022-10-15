// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity =0.8.17;

import "./Whitelistable.sol";
import "./RoyaltyPaymentSplitter.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @custom:security-contact gilgames@heroesvale.com
contract FoodFightNFT is
    ERC721,
    ERC721Enumerable,
    ERC2981,
    ReentrancyGuard,
    Whitelistable,
    Pausable,
    Ownable
{
    uint256 public constant MAX_SUPPLY = 40;
    uint256 public constant WL_MINT_DURATION = 10 minutes;
    address public constant DEV = 0xA2a8707AAACf1c5651A5FCD547B1F454AF2fb63D;
    uint256 public constant DEV_CUT = 1000;
    address public constant MANAGER =
        0x49b18DfD1ED0e79d20A5Ad02b3FE197D85D17fFB;
    uint256 public constant MANAGER_CUT = 2000;
    address public constant CURATOR =
        0x8fE4E9cD42c09d71c3CB590F7C2949ca94065001;
    uint256 public constant CURATOR_CUT = 7000; // 50% of the mint gets delivered to the artist
    uint256 public constant TOTAL_CUT = DEV_CUT + MANAGER_CUT + CURATOR_CUT;

    RoyaltyPaymentSplitter public immutable ROYALTY_PAYMENT_SPLITTER;

    uint256 public mintStartTimestamp;
    uint256 public mintPrice;
    string public baseURI;

    error MaxSupplyReached();
    error InvalidAmount();
    error MintPriceNotPaid();
    error MintingNotStarted();
    error NonExistentTokenId();
    error ArrayLengthMismatch();
    error RoyaltyTooHigh();
    error TransferFailed(address recipient);

    event MintPriceChanged(uint256 previousMintPrice, uint256 newMintPrice);
    event MintStartTimestampChanged(
        uint256 previousMintStartTimestamp,
        uint256 newMintStartTimestamp
    );
    event BaseURIChanged(string previousBaseURI, string newBaseURI);
    event NewWhitelistMint(address indexed minter, uint256 tokenId);
    event NewPublicMint(address indexed minter, uint256 tokenId);

    constructor() ERC721("Food Fight", "FF") {
        mintStartTimestamp = 1666112400; // 2022-10-18T17:00:00Z
        mintPrice = 1.5 ether;
        baseURI = "ipfs://bafybeifi5salvkaibvpruns4aj2s4uy6gw7czkxvrn5drbqekmt535u6je/"; // unrevealed metadata

        address[] memory recipients = new address[](3);
        recipients[0] = DEV;
        recipients[1] = MANAGER;
        recipients[2] = CURATOR;

        uint256[] memory shares = new uint256[](3);
        shares[0] = DEV_CUT;
        shares[1] = MANAGER_CUT;
        shares[2] = CURATOR_CUT;

        ROYALTY_PAYMENT_SPLITTER = new RoyaltyPaymentSplitter(
            recipients,
            shares
        );
        super._setDefaultRoyalty(address(ROYALTY_PAYMENT_SPLITTER), 600);

        _mint(MANAGER);
        _mint(DEV);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _mint(address to) private {
        uint256 tokenId = totalSupply() + 1;
        if (tokenId > MAX_SUPPLY) {
            revert MaxSupplyReached();
        }

        _safeMint(to, tokenId);
    }

    function _whitelistMint() private {
        if (whitelistSpots[msg.sender] == 0) {
            revert Whitelistable.NotEnoughWhitelistSpots();
        }

        _removeWhitelistSpots(msg.sender, 1);
        emit NewWhitelistMint(msg.sender, totalSupply() + 1);
        _mint(msg.sender);
    }

    function _publicMint() private {
        emit NewPublicMint(msg.sender, totalSupply() + 1);
        _mint(msg.sender);
    }

    function mint(uint256 amount) public payable whenNotPaused nonReentrant {
        if (block.timestamp < mintStartTimestamp) {
            revert MintingNotStarted();
        }

        if (amount != 1) {
            revert InvalidAmount();
        }

        if (msg.value < mintPrice) {
            revert MintPriceNotPaid();
        }

        if (block.timestamp < mintStartTimestamp + WL_MINT_DURATION) {
            _whitelistMint();
        } else {
            _publicMint();
        }

        uint256 curatorCut = (mintPrice * CURATOR_CUT) / TOTAL_CUT;
        (bool success, ) = CURATOR.call{value: curatorCut}("");
        if (!success) {
            revert TransferFailed(CURATOR);
        }

        uint256 managerCut = (mintPrice * MANAGER_CUT) / TOTAL_CUT;
        (success, ) = MANAGER.call{value: managerCut}("");
        if (!success) {
            revert TransferFailed(MANAGER);
        }

        uint256 devCut = mintPrice - curatorCut - managerCut;
        (success, ) = DEV.call{value: devCut}("");
        if (!success) {
            revert TransferFailed(DEV);
        }

        uint256 excessPayment = msg.value - mintPrice;
        if (excessPayment == 0) {
            return;
        }

        (success, ) = msg.sender.call{value: excessPayment}("");
        if (!success) {
            revert TransferFailed(msg.sender);
        }
    }

    function addWhitelistSpots(address _addr, uint256 _amount)
        public
        onlyOwner
    {
        _addWhitelistSpots(_addr, _amount);
    }

    function addWhitelistSpots(
        address[] calldata _addresses,
        uint256[] calldata _amounts
    ) public onlyOwner {
        if (_addresses.length != _amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < _addresses.length; i++) {
            addWhitelistSpots(_addresses[i], _amounts[i]);
        }
    }

    function removeWhitelistSpots(address _addr, uint256 _amount)
        public
        onlyOwner
    {
        _removeWhitelistSpots(_addr, _amount);
    }

    function clearWhitelistSpots(address _addr) public onlyOwner {
        _clearWhitelistSpots(_addr);
    }

    function tokensOfOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        }

        uint256[] memory tokens = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = tokenOfOwnerByIndex(owner, i);
        }

        return tokens;
    }

    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        uint256 previousMintPrice = mintPrice;
        mintPrice = _mintPrice;
        emit MintPriceChanged(previousMintPrice, mintPrice);
    }

    function setMintStartTimestamp(uint256 _mintStartTimestamp)
        public
        onlyOwner
    {
        uint256 previousMintStartTimestamp = mintStartTimestamp;
        mintStartTimestamp = _mintStartTimestamp;
        emit MintStartTimestampChanged(
            previousMintStartTimestamp,
            mintStartTimestamp
        );
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        string memory previousBaseURI = baseURI;
        baseURI = baseURI_;
        emit BaseURIChanged(previousBaseURI, baseURI_);
    }

    function setDefaultRoyalty(address recipient, uint96 royaltyBps)
        public
        onlyOwner
    {
        if (royaltyBps > 1000) {
            revert RoyaltyTooHigh();
        }

        super._setDefaultRoyalty(recipient, royaltyBps);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        if (!success) {
            revert TransferFailed(msg.sender);
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
