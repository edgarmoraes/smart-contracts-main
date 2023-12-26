// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
//import "@openzeppelin/contracts/utils/Counters.sol";
//import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract Marketplace is Ownable, ReentrancyGuard {

    //setup libraries
    using SafeMath for uint256;
    //using Counters for Counters.Counter;

    //declarations
    uint256 public marketFee;

    //uint256 public creatorFee;
    uint256 public itemCount;
    //Counters.Counter private itemCount;
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    struct Item{
        uint256 itemId;
        ERC721 nft;
        uint256 tokenId;
        uint256 price;
        address payable seller;
        address payable creator;
        bool sold;
        uint256 creatorFee;
    }

    mapping(uint256 => Item) public Items;

    //events
    event newItem (
        uint256 itemId,
        address indexed nft,
        uint256 tokenId,
        uint256 price,
        address indexed seller,
        address indexed creator
    );

    event itemSold (
        uint256 itemId,
        address indexed nft,
        uint256 tokenId,
        uint256 price,
        address indexed seller,
        address indexed buyer
    );

    //modifiers
    modifier onlySeller(uint256 _itemId) {
        require(!Items[_itemId].sold, "Item already sold or canceled.");
        require(msg.sender == Items[_itemId].seller, "Only the seller can do this.");
        _;
    }

    modifier itemExists(uint256 _itemId){
        require (_itemId > 0 && _itemId <= itemCount, "Item does not exists.");
        _;
    }

    modifier onlyCreator(uint256 _itemId){
        require (msg.sender == Items[_itemId].creator, "Only the NFT contract creator can change the royalty fee.");
        _;
    }

    //contract constructor
    constructor(uint256 _marketFee/*, uint256 _creatorFee*/){
        marketFee = _marketFee;
        //creatorFee = _creatorFee;
    }

    //Utility functions
    function checkRoyalties(ERC721 _nft) internal view returns (bool) {
        (bool success) = IERC165(_nft).supportsInterface(_INTERFACE_ID_ERC2981);
        return success;
    }

    //Set functions
    function setMarketFee(uint256 _marketFee) public onlyOwner {
        marketFee = _marketFee;
    }

    //Get functions
    function getMarketFee() public view returns(uint256){
        return(marketFee);
    }

    function getPrice(uint256 _itemId) itemExists(_itemId) public view returns(uint256){
        return(Items[_itemId].price);
    }

    function getSeller(uint256 _itemId) itemExists(_itemId) public view returns(address){
        return(Items[_itemId].seller);
    }

    function getCreator(uint256 _itemId) itemExists(_itemId) public view returns(address){
        return(Items[_itemId].creator);
    }

    function getNftContract(uint256 _itemId) itemExists(_itemId) public view returns(address){
        return(address(Items[_itemId].nft));
    }
    
    function getTokenId(uint256 _itemId) itemExists(_itemId) public view returns(uint256){
        return(Items[_itemId].tokenId);
    }

    function getSoldState(uint256 _itemId) itemExists(_itemId) public view returns(bool){
        return(Items[_itemId].sold);
    }

    //Check value functions
    function checkValueToMarket(uint256 _itemId) itemExists(_itemId) public view returns (uint256){
        return(Items[_itemId].price.mul(marketFee).div(100));
    }

    function checkValueToCreator(uint256 _itemId) itemExists(_itemId) public view returns (uint256){
        return(Items[_itemId].price.mul(Items[_itemId].creatorFee).div(100));
    }

    function checkValueToSeller(uint256 _itemId) itemExists(_itemId) public view returns (uint256){
        return( Items[_itemId].price.sub(Items[_itemId].price.mul(marketFee).div(100))
        .sub(Items[_itemId].price.mul(Items[_itemId].creatorFee).div(100))  );
    }

    //Financial functions
    function contractBalance() public view onlyOwner returns(uint256) {
        return address(this).balance;
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > tx.gasprice, "gas > balance.");
        payable(owner()).transfer(address(this).balance);
    }

    // function getTotalPrice(uint256 _itemId) view public returns(uint256) {
    //     return (Items[_itemId].price.mul(marketFee.add(100)).div(100));
    // }

    function setCreatorFee(uint256 _creatorFee, uint256 _itemId) public onlyCreator(_itemId) {
        require(_creatorFee <= 10 , "Max permited fee is 10%.");
        Items[_itemId].creatorFee = _creatorFee;
    }

    //Marketplace functions
    function makeItem(ERC721 _nft, uint256 _tokenId, uint256 _price, address creator, uint256 creatorFee) external nonReentrant {
        require(_price > 0, "Valor invalido.");
        itemCount++;

        //trasnfer nft
        _nft.transferFrom(msg.sender, address(this), _tokenId);
        
        //add item to mapping
        Items[itemCount] = Item (
            itemCount,
            _nft,
            _tokenId,
            _price,
            payable(msg.sender),
            payable(creator),
            false,
            creatorFee
        );

        //emit event
        emit newItem(
            itemCount,
            address(_nft),
            _tokenId,
            _price,
            msg.sender,
            creator
        );
    }

    function cancelItem (uint256 _itemId) external itemExists(_itemId) onlySeller(_itemId){
        Item storage item = Items[_itemId];

        //return NFT to seller
        item.nft.transferFrom(address(this), msg.sender, item.tokenId);
        item.sold = true;        
    }

    function buyItem (uint256 _itemId) external payable nonReentrant itemExists(_itemId) {
        //uint256 _totalPrice = getTotalPrice(_itemId);
        Item storage item = Items[_itemId];
        uint256 _creatorRoyalty = (item.price.mul(item.creatorFee)).div(100);
        uint256 _marketFees = (item.price.mul(marketFee)).div(100);
        require(!item.sold, "Item already sold.");
        require(msg.value >= item.price, "Price not met.");

        //making payments        
        item.seller.transfer( (item.price.sub(_creatorRoyalty)).sub(_marketFees) );
        item.creator.transfer(_creatorRoyalty);
        payable(owner()).transfer(_marketFees);


        //transfer NFT to buyer
        item.nft.transferFrom(address(this), msg.sender, item.tokenId);
        item.sold = true;
        
        //emit event
        emit itemSold (
            item.itemId,
            address(item.nft),
            item.tokenId,
            item.price,
            item.seller,
            msg.sender
        );
    }

    // Remove contract from the blockchain
    // selfdestruct sends all remaining Ether stored in the contract to a designated address.
    // function close() public onlyOwner{
    //     selfdestruct(payable(owner()));
    // }
}
