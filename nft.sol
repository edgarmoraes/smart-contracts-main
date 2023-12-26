// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract NFTcontract is ERC721, ERC2981, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {
    // Libraries setup
    using Counters for Counters.Counter;

     // Declarations
    Counters.Counter private _tokenIdCounter;
    uint256 private MAX_SUPPLY = 10000 ;

    uint256 private mintRate;
    string private nm;
    string private symb;

    constructor(uint96 _royaltyFeesInBips, 
    string memory _nm, 
    string memory _symb, 
    uint256 _mintRate) ERC721(_nm, _symb) {
        setRoyaltyInfo(owner(), _royaltyFeesInBips);
        nm = _nm;
        symb = _symb;
        mintRate = _mintRate;
    }

    // Get functions
    function getMintRate() public view onlyOwner returns(uint256) {
        return(mintRate);
    }

    function getMaxSupply() public view onlyOwner returns(uint256) {
        return(MAX_SUPPLY);
    }

    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return tokenURI(tokenId);
    }

    // Set functions
    function setMintRate(uint256 _mintRate) public onlyOwner {
        mintRate = _mintRate;
    }

    // function setMaxSupply(uint256 _maxSupply) public onlyOwner {
    //     maxSupply = _maxSupply;
    // }

    function setTokenURI(uint256 tokenId, string memory uri) public onlyOwner {
       _setTokenURI(tokenId, uri);
    }

    function setRoyaltyInfo(address _receiver, uint96 _royaltyFeesInBips) public onlyOwner {
        _setDefaultRoyalty(_receiver, _royaltyFeesInBips);
    }

    // Mint functions
    function safeMint(string memory uri) public payable {
        require(totalSupply() < MAX_SUPPLY, "Quantidade maxima de NFTs atingida.");
        require(msg.value >= mintRate, "Valor insuficiente.");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function ownerMint(string memory uri) public onlyOwner {
        require(totalSupply() < MAX_SUPPLY, "Quantidade maxima de NFTs atingida.");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // Financial functions
    function contractBalance() public view onlyOwner returns(uint256) {
        return address(this).balance;
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > tx.gasprice);
        payable(owner()).transfer(address(this).balance);
    }


    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
