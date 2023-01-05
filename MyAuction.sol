// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SampleToken.sol";
import "hardhat/console.sol";

contract Auction is Ownable {
    SampleToken internal _tokenContract;

    uint256 public auction_start;
    uint256 public auction_end;
    uint256 public highestBid;
    address public highestBidder;

    enum auction_state {
        CANCELLED,
        STARTED
    }

    struct Car {
        string brand;
        string rNumber;
        address owner;
    }

    Car public prize;
    address[] bidders;

    mapping(address => uint256) public bids;

    auction_state public STATE;

    modifier an_ongoing_auction() {
        require(
            block.timestamp <= auction_end && STATE == auction_state.STARTED,
            "You can't continue, the auction has ended"
        );
        _;
    }

    modifier an_ended_auction() {
        require(
            block.timestamp > auction_end || STATE == auction_state.CANCELLED,
            "You can't continue, the auction is still open"
        );
        _;
    }

    modifier already_bid() {
        address sender = _msgSender();
        require(bids[sender] > 0, "You already made a bid!");
        _;
    }

    function bid(uint256 amountTokBid) public payable virtual returns (bool) {}

    function withdraw(bool wantToClaimPrize) public virtual returns (bool) {}

    function cancel_auction() external virtual returns (bool) {}

    event BidEvent(address indexed highestBidder, uint256 highestBid);
    event WithdrawalEvent(address withdrawer, uint256 amount);
    event CanceledEvent(string message, uint256 time);
}

contract MyAuction is Auction {
    constructor(
        SampleToken tokenContract,
        uint256 _biddingTime,
        string memory _brand,
        string memory _rNumber
    ) {
        _tokenContract = tokenContract;
        auction_start = block.timestamp;
        auction_end = auction_start + _biddingTime * 1 hours;
        STATE = auction_state.STARTED;
        prize.brand = _brand;
        prize.rNumber = _rNumber;
        prize.owner = _msgSender();
    }

    fallback() external payable {}

    receive() external payable {}

    function bid(uint256 amountTokBid)
        public
        payable
        override
        an_ongoing_auction
        returns (bool)
    {
        address sender = _msgSender();
        require(
            _tokenContract.balanceOf(sender) >= amountTokBid,
            "You do not own enough $TOK to make this bid!"
        );
        require(
            _tokenContract.allowance(sender, address(this)) >= amountTokBid,
            "This contract is not allowed to take this bid from you! Please allow us to withdraw it and try again!"
        );
        require(amountTokBid > highestBid, "You did not bid enough!");
        highestBidder = sender;
        highestBid = amountTokBid;
        bidders.push(sender);
        bids[sender] = amountTokBid;

        _tokenContract.transferFrom(sender, address(this), amountTokBid);

        emit BidEvent(highestBidder, highestBid);

        return true;
    }

    function withdraw(bool wantToClaimPrize)
        public
        override
        an_ended_auction
        returns (bool)
    {
        address sender = _msgSender();

        uint256 amount;

        if (sender == highestBidder && wantToClaimPrize) {
            amount = highestBid;
            prize.owner = sender;
            _tokenContract.transfer(owner(), highestBid);
        } else {
            amount = bids[sender];
            bids[sender] = 0;

            _tokenContract.transfer(sender, amount);
        }

        emit WithdrawalEvent(msg.sender, amount);

        return true;
    }

    function cancel_auction()
        external
        override
        onlyOwner
        an_ongoing_auction
        returns (bool)
    {
        STATE = auction_state.CANCELLED;
        emit CanceledEvent("Auction Cancelled", block.timestamp);
        return true;
    }

    function destruct_auction()
        external
        onlyOwner
        an_ended_auction
        returns (bool)
    {
        for (uint256 i = 0; i < bidders.length; i++) {
            if (bids[bidders[i]] > 0) {
                uint256 amount = bids[bidders[i]];
                bids[bidders[i]] = 0;

                _tokenContract.transfer(bidders[i], amount);
            }
            assert(bids[bidders[i]] == 0);
        }

        selfdestruct(payable(owner()));
        return true;
    }
}
