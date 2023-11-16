// SPDX-License-Identifier:MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./NFT.sol";

contract NFTMarketplace is Ownable, ReentrancyGuard{

    string private constant SIMPLE_ACTION = "fixed_price";
    string private constant OFFER_ACTION = "open_for_bids";
    string private constant AUCTION_ACTION = "timed_auction";


    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _offerIds;
    Counters.Counter private _auctionIds;

    uint256 marketplaceServiceFee = 20; // In the percentage
    //*******Authorizers for the auto functionalities**********
    mapping(address => bool) public authorizers;
    //*****************end*********************

    //*******Owners of the marketplace**********
    address[] private multipleOwners;
    //*****************end*********************

    struct ItemStruct {
        string tokenURI;
        uint256 tokenId;
        address erc721Address;
        uint256 price;
        address payable owner; // who bought this item 50000000000000000000
        string category;
        bool onSale; // Item on sale or not
        string saleType; // Type of the sale i.e. fixed_price, open_for_bids and timed_auction
        address createdBy;
        uint256 createdAt;
        uint256 updatedAt;
    }

    struct UserOfferStruct {
        uint256 price;
        uint256 from; // Offer started
        uint256 to; // Offer ended
        string status;
        address createdBy;
        uint256 createdAt;
    }

    struct OfferStruct {
        uint256 itemId;
        uint32 offererCount;
        mapping(uint32 => UserOfferStruct) offerers; // Who offers for the selected item
        uint256 price; // offer accepted price
        bool accepted;
        address createdBy;
        uint256 createdAt;
    }

    struct AuctionStruct {
        uint256 itemId;
        uint256 initialBid; // Initial bid of the auction
        uint256 finalBid; // Final bid of the auction after completion
        uint256 startTime;
        uint256 endTime;
        address winner;
        string status; // initialize, completed, canceled
        address createdBy; // Initial bidder and owner of the item
        address updatedBy; // Current bidder of the auction
        uint256 createdAt;
        uint256 updatedAt;
    }

    mapping(uint256 => ItemStruct) private Items;
    mapping(uint256 => OfferStruct) private Offers;
    mapping(uint256 => AuctionStruct) private Auctions;
function getIdAuction(uint256 a)public view returns(uint256)
{
    return Auctions[a].itemId;
}
    // events
    event ItemEvent(
        uint256 indexed itemId,
        string tokenURI,
        uint256 tokenId,
        address indexed erc721Address,
        uint256 price,
        address owner,
        string category,
        string saleType,
        string status,
        address createdBy,
        uint256 createdAt
    );

    // status : on_sale, created, accepted, rejected, refunded
    event OfferEvent(
        uint256 indexed itemId,
        uint256 indexed offerId,
        address offerer,
        uint256 price,
        uint256 offerFrom,
        uint256 offerTo,
        string status,
        address createdBy,
        uint256 createdAt
    );

    // status : on_sale, created, refund, winner
    event AuctionEvent(
        uint256 indexed itemId,
        uint256 indexed auctionId,
        uint256 initialBid,
        uint256 prevBid,
        uint256 lastBid,
        address bidder,
        address prevBidder,
        string status,
        address createdBy,
        uint256 createdAt
    );

    function _keccakCheck(
        string memory type1,
        string memory type2
    ) private pure returns (bool) {
        return
            keccak256(abi.encodePacked(type1)) ==
            keccak256(abi.encodePacked(type2));
    }

    //****************add and delete authorizers address**************************
    // type : owner or authorizer
    modifier onlyAuthorizerOrOwner(string memory _type) {
        bool isMultiOwner = false; //
        for (uint256 i = 0; i < multipleOwners.length; i++) {
            if (multipleOwners[i] == msg.sender) {
                isMultiOwner = true;
            }
        }
        if (_keccakCheck(_type, "owner")) {
            require(
                isMultiOwner || owner() == msg.sender,
                "You are not authenticated!"
            );
        } else if (_keccakCheck(_type, "authorizer")) {
            require(
                authorizers[msg.sender] || owner() == msg.sender,
                "You are not authenticated!"
            );
        } else if (_keccakCheck(_type, "both")) {
            require(
                authorizers[msg.sender] ||
                    owner() == msg.sender ||
                    isMultiOwner,
                "You are not authenticated!"
            );
        } else {
            revert("You are not authenticated!");
        }
        _;
    }

    // Return marketplace fee
    function getMarketplaceServiceFee() public view returns (uint256) {
        return marketplaceServiceFee;
    }

    // Set marketplace fee
    function setMarketplaceServiceFee(
        uint256 _fee
    ) public onlyAuthorizerOrOwner("owner") {
        require(_fee <= 40, "Service fee must be less than 30%!");
        marketplaceServiceFee = _fee;
    }

    // type : owner or authorizer
    function addAuthorizerOrOwner(
        address[] memory _addresses,
        string memory _type
    ) public onlyAuthorizerOrOwner("both") {
        require(
            _keccakCheck(_type, "owner") || _keccakCheck(_type, "authorizer"),
            "Invalid type!"
        );
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (_keccakCheck(_type, "owner")) {
                multipleOwners.push(_addresses[i]);
            } else {
                authorizers[_addresses[i]] = true;
            }
        }
    }

    // type : owner or authorizer
    function deleteAuthorizerOrOwner(
        address _address,
        string memory _type
    ) public onlyAuthorizerOrOwner("both") {
        require(
            _keccakCheck(_type, "owner") || _keccakCheck(_type, "authorizer"),
            "Invalid type!"
        );
        if (_keccakCheck(_type, "owner")) {
            for (uint256 i = 0; i < multipleOwners.length; i++) {
                if (multipleOwners[i] == _address) {
                    delete multipleOwners[i];
                }
            }
        } else {
            delete authorizers[_address];
        }
    }

    function createItem(
        address _address,
        string memory _tokenUri,
        string memory _category,
        // string memory _genre,
        uint256 _price
    ) public payable returns (uint256, uint256) {
        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        NFT nft = NFT(_address);

        // calling createToken function from NFT.sol contract
        uint256 tokenId = nft.createToken(_tokenUri);

        // transferring nft to msg.sender from address(this)
        nft.transferFrom(address(this), msg.sender, tokenId);

        Items[itemId] = ItemStruct({
            tokenURI: _tokenUri,
            tokenId: tokenId,
            erc721Address: _address,
            price: _price,
            owner: payable(msg.sender),
            category: _category,
            onSale: false,
            saleType: "",
            createdBy: msg.sender,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        emit ItemEvent(
            itemId,
            _tokenUri,
            tokenId,
            _address,
            _price,
            msg.sender,
            _category,
            "",
            "created",
            msg.sender,
            block.timestamp
        );

        return (itemId, tokenId);
    }

    // @notice List NFT on Marketplace
    function listItem(
        uint256 _itemId,
        uint256 _price,
        string memory _type,
        uint256 _startTime,
        uint256 _endTime
    ) external returns (uint256) {
        require(Items[_itemId].tokenId > 0, "Item not created yet!");
        require(!Items[_itemId].onSale, "Item already on sale!");
        require(msg.sender != address(0), "Invalid msg.sender value!");

        
        require(checkNftOwner(_itemId, msg.sender), "You are not nft owner!");

        uint256 listItemId = 0;
//**Removed paymentMEthod from Auction***********************************************************
        if (_keccakCheck(_type, AUCTION_ACTION)) {
            listItemId = setOnAuctionSale(
                _itemId,
                _price,
                _startTime,
                _endTime
                // _paymentMethod
            );
        } else if (_keccakCheck(_type, SIMPLE_ACTION)) {
            require(_price > 0, "Price should be greater than zero");

            // Update Item Data
            Items[_itemId].price = _price;
            Items[_itemId].onSale = true;
            Items[_itemId].saleType = _type;
            Items[_itemId].updatedAt = block.timestamp;

            ItemStruct storage item = Items[_itemId];
            emit ItemEvent(
                _itemId,
                item.tokenURI,
                item.tokenId,
                item.erc721Address,
                _price,
                msg.sender,
                item.category,
                _type,
                "list_on_fixed_price",
                msg.sender,
                block.timestamp
            );
        } else if (_keccakCheck(_type, OFFER_ACTION)) {
            listItemId = setOnOfferSale(_itemId);
        } else {
            revert("Enter correct type");
        }
        return (listItemId);
    }

    function cancelListedItem(
        string memory _type,
        uint256 _typeId,
        uint256 _itemId
    ) external {
        require(msg.sender != address(0), "Invalid msg.sender value!");

        string memory status;
        if (_keccakCheck(_type, AUCTION_ACTION)) {
            // refund amount to last bidder

            require(Auctions[_typeId].itemId > 0, "Invalid auction id!");
            require(_keccakCheck(Auctions[_typeId].status, "initialize"),"not listed or complete");
            address winner = Auctions[_typeId].winner;
            _itemId = Auctions[_typeId].itemId;
            require(
                checkNftOwner(_itemId, msg.sender),
                "You are not authenticated!"
            );

            if (
                winner != address(0) &&
                winner != address(this) &&
                !checkNftOwner(Auctions[_typeId].itemId, winner) &&
                _keccakCheck(Auctions[_typeId].status, "initialize")
            ) {
                handlepayment(
                    // Auctions[_typeId].paymentMethod,
                    // address(this),
                    winner,
                    Auctions[_typeId].finalBid
                );
            }
            Auctions[_typeId].winner = address(this);
            Auctions[_typeId].status = "canceled";
            Auctions[_typeId].updatedBy = msg.sender;
            Auctions[_typeId].updatedAt = block.timestamp;
            status = "canceled_from_auction";
        } else if (_keccakCheck(_type, SIMPLE_ACTION)) {
            require(
                checkNftOwner(_itemId, msg.sender),
                "You are not authenticated!"
            );
            status = "canceled_from_fixed_price";
        } else if (_keccakCheck(_type, OFFER_ACTION)) {
            _itemId = Offers[_typeId].itemId;
            require(
                checkNftOwner(_itemId, msg.sender),
                "You are not authenticated!"
            );
            
            require(Offers[_typeId].accepted == false,"not listed or accepted");
            Offers[_typeId].accepted = true;

            refundOfferAmountToOfferers(_typeId, address(0));
            status = "canceled_from_offer";
        } else {
            revert("Enter correct type");
        }

        // update item
        if (_itemId > 0) {
            callItem(_itemId, msg.sender, 0, false, "", status);
        }
    }

    // Buy Fixed Price NFT
    function buyItem(uint256 _itemId) external payable {
        require(msg.sender != address(0), "Invalid msg.sender value!");

        require(checkNftOnSale(_itemId, SIMPLE_ACTION), "Item not on sale!");

        require(
            !checkNftOwner(_itemId, msg.sender),
            "You are already a nft owner!"
        );
        require( msg.value == Items[_itemId].price,
                "Invalid Price, Please check for msg.value"
                );

        sellCalculation(_itemId, Items[_itemId].price, msg.sender);
    }

    function setOnOfferSale(
        uint256 _itemId
    ) internal returns (uint256) {
        _offerIds.increment();
        uint256 offerId = _offerIds.current();
        Offers[offerId].itemId = _itemId;
        Offers[offerId].offererCount = 0;
        Offers[offerId].price = 0;
        Offers[offerId].accepted = false;
        Offers[offerId].createdBy = msg.sender;
        Offers[offerId].createdAt = block.timestamp;
        emit OfferEvent(
            _itemId,
            offerId,
            address(0),
            0,
            0,
            0,
            "on_sale",
            msg.sender,
            block.timestamp
        );

        // update item
        callItem(
            _itemId,
            msg.sender,
            0,
            true,
            OFFER_ACTION,
            "list_on_offer"
        );
        return (offerId);
    }

    // @notice Offer listed NFT
    function createOfferForItem(
        uint256 _offerId,
        uint256 _offerPrice,
        uint256 _offerFrom,
        uint256 _offerTo
    ) public payable {
        require(msg.sender != address(0), "Invalid msg.sender value!");
        require(Offers[_offerId].itemId > 0, "Invalid offer id!");
        require(
            checkNftOnSale(Offers[_offerId].itemId, OFFER_ACTION),
            "Item not on sale with offer!"
        );
        require(
            !checkNftOwner(Offers[_offerId].itemId, msg.sender),
            "You are already a nft owner!"
        );

        require(_offerPrice > 0, "Offer price should be greater than 0!");
        //*******************did changes here*****************************************
        require(
            block.timestamp <= _offerFrom && _offerFrom < _offerTo,
            "Offer from should be greater than timestamp and less than offer expire time!"
        );
            require(
                msg.value == _offerPrice,
                "Invalid Price, Please check for msg.value"
            );

        Offers[_offerId].offerers[
            Offers[_offerId].offererCount
        ] = UserOfferStruct({
            price: _offerPrice,
            from: _offerFrom, // Offer started
            to: _offerTo, // Offer ended
            status: "created",
            createdBy: msg.sender,
            createdAt: block.timestamp
        });
        Offers[_offerId].offererCount += 1;

        emit OfferEvent(
            Offers[_offerId].itemId,
            _offerId,
            msg.sender,
            _offerPrice,
            _offerFrom,
            _offerTo,
            "created",
            msg.sender,
            block.timestamp
        );
    }

    //acceptOffer function can also be use by the owner of the marketplace
    // new paramete is add as _offererCount for adding the filter for start time and endtime
    // the offererCount starts from 0 and not from 1
    function acceptOfferForItem(
        address _offerer,
        uint256 _offerId
    ) public payable {
        require(msg.sender != address(0), "Invalid msg.sender value!");
        require(
            _offerer != address(0) && _offerer != address(this),
            "Invalid offerer address!"
        );
        require(Offers[_offerId].itemId > 0, "Invalid offer id!");

        require(
            checkNftOnSale(Offers[_offerId].itemId, OFFER_ACTION),
            "Item not on sale with offer!"
        );

        require(
            checkNftOwner(Offers[_offerId].itemId, msg.sender),
            "You are not nft owner!"
        );

        require(
            _checkAddressInOfferOrAuction(_offerer, "offer", _offerId),
            "Invalid offerer address!"
        );

        for (uint32 i = 0; i < Offers[_offerId].offererCount; i++) {
            UserOfferStruct memory offerer = Offers[_offerId].offerers[i];

            if (offerer.createdBy == _offerer) {
                require(
                    block.timestamp >= offerer.from &&
                        block.timestamp <= offerer.to,
                    "Offer ended or not started"
                );

                // Transfer money calculation
                sellCalculation(
                    Offers[_offerId].itemId,
                    offerer.price,
                    offerer.createdBy
                );
                Offers[_offerId].price = offerer.price;
                // Event created for accept offer by item owner

                emit OfferEvent(
                    Offers[_offerId].itemId,
                    _offerId,
                    _offerer,
                    offerer.price,
                    offerer.from,
                    offerer.to,
                    "accepted",
                    msg.sender,
                    block.timestamp
                );
            }
        }

        refundOfferAmountToOfferers(_offerId, _offerer);
        Offers[_offerId].accepted = true;
    }

    function refundOfferAmountToOfferers(
        uint256 _offerId,
        address _offerer
    ) private {
        // Refund amount to other offerer
        for (uint32 i = 0; i < Offers[_offerId].offererCount; i++) {
            if (
                _offerer != address(0) &&
                _offerer != address(this) &&
                Offers[_offerId].offerers[i].createdBy == _offerer
            ) {
                Offers[_offerId].offerers[i].status = "accepted";
            } else {
                if (
                    _keccakCheck(Offers[_offerId].offerers[i].status, "created")
                ) {
                    handlepayment(
                        // Offers[_offerId].paymentMethod,
                        // address(this),
                        Offers[_offerId].offerers[i].createdBy,
                        Offers[_offerId].offerers[i].price
                    );
                }
                Offers[_offerId].offerers[i].status = "refunded";
            }
        }
    }

    //*********************************************************************************

    //@notice Offerer cancel or refund offerring
    // can be used by marketplace admin and item owner

    function refundToOfferer(uint256 _offerId, address _refundTo) external {
        require(Offers[_offerId].itemId > 0, "Invalid offer id!");
        require(
            checkNftOnSale(Offers[_offerId].itemId, OFFER_ACTION),
            "Item not on sale with offer!"
        );
        require(
            _refundTo != address(0) &&
                _refundTo != address(this) &&
                _checkAddressInOfferOrAuction(_refundTo, "offer", _offerId),
            "Invalid refunded address!"
        );

        for (uint32 i = 0; i < Offers[_offerId].offererCount; i++) {
            UserOfferStruct memory offerer = Offers[_offerId].offerers[i];
            if (
                offerer.createdBy == _refundTo &&
                _keccakCheck(offerer.status, "created")
            ) {
                handlepayment(
                    offerer.createdBy,
                    offerer.price
                );

                Offers[_offerId].offerers[i].status = "refunded";

                emit OfferEvent(
                    Offers[_offerId].itemId,
                    _offerId,
                    _refundTo,
                    offerer.price,
                    offerer.from,
                    offerer.to,
                    "refunded",
                    msg.sender,
                    block.timestamp
                );
            }
        }
    }

    // @notice Create autcion
    function setOnAuctionSale(
        uint256 _itemId,
        uint256 _minBid,
        uint256 _startTime,
        uint256 _endTime
    ) internal returns (uint256) {
        require(
            _startTime >= block.timestamp && _endTime > _startTime,
            "Start time should be greater than block timestamp and End time should be greater than start time!"
        );

        _auctionIds.increment();
        uint256 auctionId = _auctionIds.current();


        Auctions[auctionId].itemId = _itemId;
        Auctions[auctionId].initialBid = _minBid;
        Auctions[auctionId].finalBid = _minBid;
        Auctions[auctionId].startTime = _startTime;
        Auctions[auctionId].endTime = _endTime;
        Auctions[auctionId].winner = address(0);
        Auctions[auctionId].status = "initialize";
        Auctions[auctionId].createdBy = msg.sender;
        Auctions[auctionId].updatedBy = msg.sender;
        Auctions[auctionId].createdAt = block.timestamp;
        Auctions[auctionId].updatedAt = block.timestamp;

        emit AuctionEvent(
            _itemId,
            auctionId,
            _minBid,
            _minBid,
            _minBid,
            msg.sender,
            address(0),
            "initialize",
            msg.sender,
            block.timestamp
        );

        // update item
        callItem(
            _itemId,
            msg.sender,
            0,
            true,
            AUCTION_ACTION,
            "list_on_auction"
        );
        return (auctionId);
    }

    // @notice Bid place time auction
    function bidPlace(uint256 _auctionId, uint256 _bidPrice) external payable {
        require(
            msg.sender != address(0) && msg.sender != address(this),
            "Invalid msg.sender value!"
        );
        require(Auctions[_auctionId].itemId > 0, "Invalid auction id!");

        require(
            checkNftOnSale(Auctions[_auctionId].itemId, AUCTION_ACTION),
            "Item not on auction sale!"
        );

        require(
            !checkNftOwner(Auctions[_auctionId].itemId, msg.sender),
            "You are already a nft owner!"
        );
        //*********************Cannot place bid Auction before time**********************
        require(
            Auctions[_auctionId].startTime <= block.timestamp,
            "Auction not started!"
        );

        require(
            _keccakCheck(Auctions[_auctionId].status, "initialize") &&
                block.timestamp <= Auctions[_auctionId].endTime,
            "Auction expired or completed or removed!"
        );

        require(
            Auctions[_auctionId].winner != msg.sender,
            "You are already a higer bidder!"
        );

        // ***************************************************************************************************************
        require(
            _bidPrice > 0 && _bidPrice > Auctions[_auctionId].finalBid,
            "Bid price should be greater than current bid price!"
        );
            require(
                msg.value == _bidPrice,
                "Invalid Price, Please check for msg.value"
            );
        // }

        // refund amount to last bidder
        uint256 lastBid = Auctions[_auctionId].finalBid;
        address lastBidder = Auctions[_auctionId].winner;
        if (lastBidder != address(0) && lastBidder != address(this)) {
            handlepayment(
                lastBidder, 
                lastBid);
        }

        Auctions[_auctionId].finalBid = _bidPrice;
        Auctions[_auctionId].winner = msg.sender;
        Auctions[_auctionId].updatedBy = msg.sender;
        Auctions[_auctionId].updatedAt = block.timestamp;

        emit AuctionEvent(
            Auctions[_auctionId].itemId,
            _auctionId,
            Auctions[_auctionId].initialBid,
            lastBid,
            _bidPrice,
            msg.sender,
            lastBidder,
            "placed_bid",
            msg.sender,
            block.timestamp
        );
    }

    // working from here

    // @notice Result auction, can call by auction creator, heighest bidder, or marketplace owner only!
    function transferAuctionItem(
        uint256 _auctionId
    ) external payable {
        require(Auctions[_auctionId].itemId > 0, "Invalid auction id!");
        require(_keccakCheck(Auctions[_auctionId].status,"initialize"),"Invalid previous auction id!");
        require(msg.sender != address(0), "Invalid msg.sender value!");
        require(
            checkNftOnSale(Auctions[_auctionId].itemId, AUCTION_ACTION),
            "Item not on auction sale!"
        );

        require(
            Auctions[_auctionId].endTime < block.timestamp,
            "Auction not ended yet!"
        );

        if (
            checkNftOwner(Auctions[_auctionId].itemId, msg.sender) ||
            Auctions[_auctionId].winner == msg.sender ||
            authorizers[msg.sender] ||
            owner() == msg.sender
        ) {
            sellCalculation(
                Auctions[_auctionId].itemId,
                Auctions[_auctionId].finalBid,
                Auctions[_auctionId].winner
            );

            Auctions[_auctionId].status = "completed";
            Auctions[_auctionId].updatedBy = msg.sender;
            Auctions[_auctionId].updatedAt = block.timestamp;

            emit AuctionEvent(
                Auctions[_auctionId].itemId,
                _auctionId,
                Auctions[_auctionId].initialBid,
                Auctions[_auctionId].finalBid,
                0,
                Auctions[_auctionId].winner,
                address(0),
                "completed",
                msg.sender,
                block.timestamp
            );
        } else {
            revert("You are not winner or authenticated!");
        }
    }

    function callItem(
        uint256 _itemId,
        address owner,
        uint256 _price,
        bool onSale,
        string memory saleType,
        string memory status
    ) private {
        // Update Item Data
        ItemStruct storage item = Items[_itemId];
        if (_price > 0) {
            item.price = _price;
        }

        item.owner = payable(owner);
        item.onSale = onSale;
        item.saleType = saleType;
        item.updatedAt = block.timestamp;

        emit ItemEvent(
            _itemId,
            item.tokenURI,
            item.tokenId,
            item.erc721Address,
            _price > 0 ? _price : item.price,
            owner,
            item.category,
            // item.genre,
            saleType,
            status,
            item.createdBy,
            block.timestamp
        );
    }

    function handlepayment(
        address _to,
        uint256 _price
    ) internal nonReentrant {
            // logic for ETH payment
            (bool isPaid, ) = payable(_to).call{value: _price}("");
            require(isPaid, "Amount not sent!");
    }

    function sellCalculation(
        uint256 _itemId,
        uint256 _price,
        address _buyer
    ) private {
        ItemStruct storage item = Items[_itemId];

        uint256 serviceFee = 0;
        if (marketplaceServiceFee >= 0) {
            serviceFee = (_price * marketplaceServiceFee) / 100;
        }

        // Transfering royality fees to NFT owner
        NFT nft = NFT(item.erc721Address);
        uint256 royaltyFeeValue = nft.royaltyFee();

        uint256 royaltyFee = 0;
        if (royaltyFeeValue > 0) {
            royaltyFee = (_price * royaltyFeeValue) / 100;
        }

        uint256 remainingPrice = _price - serviceFee - royaltyFee;
            // (bool isPaidItemActualAmount, ) = payable(item.owner).call{ //remaining price send to the nft owner
            //     value: remainingPrice
            // }("");
            // require(isPaidItemActualAmount, "Amount not sent to the owner!");
            handlepayment(item.owner,remainingPrice);//remaining price send to the nft owner
//**********************************************************************************************************
        // Transfer NFT to buyer
        nft.transferFrom(item.owner, _buyer, item.tokenId);

        if (serviceFee > 0) {
            handlepayment(
                owner(),
                serviceFee
            ); //marketplace balance send to the MP Owner
        }

        if (royaltyFee > 0) {
            handlepayment(
                item.createdBy,
                royaltyFee
            );
        }

        // calling Item struct and Event form callItem
        callItem(
            _itemId,
            _buyer,
            _price,
            false,
            "",
            "buy_item"
        );
    }

    function _checkAddressInOfferOrAuction(
        address _address,
        string memory _type,
        uint256 _typeId
    ) internal view returns (bool) {
        bool status = false;
        if (_keccakCheck(_type, "offer")) {
            for (uint32 i = 0; i < Offers[_typeId].offererCount; i++) {
                if (_address == Offers[_typeId].offerers[i].createdBy) {
                    status = true;
                }
            }
        } else if (_keccakCheck(_type, "auction")) {
            if (_address == Auctions[_typeId].winner) {
                status = true;
            }
        }
        return status;
    }

    function checkNftOwner(
        uint256 _itemId,
        address _address
    ) private view returns (bool) {
        NFT nft = NFT(Items[_itemId].erc721Address);
        return nft.ownerOf(Items[_itemId].tokenId) == _address;
    }

    function checkNftOnSale(
        uint256 _itemId,
        string memory _type
    ) private view returns (bool) {
        return
            Items[_itemId].onSale &&
            _keccakCheck(Items[_itemId].saleType, _type);
    }

    function getItem(uint256 id) public view returns (ItemStruct memory) {
        return Items[id];
    }

    function getAuction(uint256 id) public view returns (AuctionStruct memory) {
        return Auctions[id];
    }

}