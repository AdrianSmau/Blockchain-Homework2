// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./SampleToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SampleTokenSale is Ownable {
    using SafeMath for uint256;

    SampleToken private _tokenContract;
    uint256 private _tokenPrice;
    uint256 private _tokensSold;

    event Sell(address indexed _buyer, uint256 indexed _amount);

    constructor(SampleToken tokenContract, uint256 tokenPrice) {
        address creator = _msgSender();
        require(
            creator == tokenContract.owner(),
            "You are not the owner of this ERC20 token!"
        );
        _tokenContract = tokenContract;
        _tokenPrice = tokenPrice;
        _tokenContract.whitelistMarketplace(address(this));
        _tokenContract.requestAllowence();
    }

    function getTokensSold() public view returns (uint256) {
        return _tokensSold;
    }

    function getTokenPrice() public view returns (uint256) {
        return _tokenPrice;
    }

    function buyTokens(uint256 _numberOfTokens) public payable {
        address sender = _msgSender();
        uint256 necessaryValue = _numberOfTokens.mul(_tokenPrice);
        require(
            msg.value >= necessaryValue,
            "You did not pay enough for the requested amount of $TOK!"
        );
        if (msg.value > necessaryValue) {
            payable(sender).transfer(msg.value - necessaryValue);
        }
        require(_numberOfTokens <= 10000, "You cannot buy more than 10k $TOK!");
        if ((_tokensSold + _numberOfTokens) / 10000 > _tokensSold / 10000) {
            _tokenContract._mint(owner(), 10000);
            _tokenContract.requestAllowence();
        }

        _tokensSold = _tokensSold.add(_numberOfTokens);
        _tokenContract.transferFrom(owner(), sender, _numberOfTokens);

        emit Sell(msg.sender, _numberOfTokens);
    }

    function endSale() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function modifyPrice(uint256 newPrice) public onlyOwner {
        _tokenPrice = newPrice;
    }
}
