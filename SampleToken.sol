// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/SafeMath.sol";

contract SampleToken is Ownable, IERC20, IERC20Metadata {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _whitelistedMarketplaces;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(uint256 _initialSupply) {
        require(_initialSupply >= 10000, "You must mint 10k $TOK or more!");
        _name = "Sample Token";
        _symbol = "TOK";
        address owner = _msgSender();
        _mint(owner, _initialSupply);
    }

    /* --- Getters and Utility functions --- */

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function isMarketplaceWhitelisted(address _marketplaceAddress)
        public
        view
        virtual
        returns (bool)
    {
        return _whitelistedMarketplaces[_marketplaceAddress];
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /* --- Transfer and Allowence Management --- */

    modifier non_mintable(address from) {
        require(from != address(0), "Cannot mint $TOK through this method!");
        _;
    }

    modifier non_burnable(address to) {
        require(to != address(0), "Cannot mint $TOK through this method!");
        _;
    }

    function _transferHelper(
        address from,
        address to,
        uint256 amount
    ) internal virtual non_mintable(from) non_burnable(to) {
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "You do not own enough $TOK!");

        _balances[from] = fromBalance.sub(amount);
        _balances[to] = _balances[to].add(amount);

        emit Transfer(from, to, amount);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _transferHelper(owner, to, amount);
        return true;
    }

    function _approveHelper(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual non_mintable(owner) non_burnable(spender) {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     *If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "You do not have enough allowance from requested address to spend!"
            );
            uint256 updatedAllowence = currentAllowance.sub(amount);
            _approveHelper(owner, spender, updatedAllowence);
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferHelper(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _approveHelper(owner, spender, amount);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        address sender = _msgSender();
        uint256 updatedAllowence = allowance(sender, spender).add(addedValue);
        _approveHelper(sender, spender, updatedAllowence);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(
            currentAllowance >= subtractedValue,
            "Amount of allowence dropped below 0!"
        );
        uint256 updatedAllowence = currentAllowance.sub(subtractedValue);
        _approveHelper(owner, spender, updatedAllowence);

        return true;
    }

    /* --- Mint and Burn functions --- */

    modifier canMint() {
        address sender = _msgSender();
        require(
            owner() == sender || _whitelistedMarketplaces[sender],
            "You are neither the Owner, nor Whitelisted!"
        );
        _;
    }

    function _mint(address account, uint256 amount)
        public
        virtual
        non_burnable(account)
        canMint
    {
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);

        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        virtual
        non_mintable(account)
    {
        uint256 accountBalance = _balances[account];
        require(
            accountBalance >= amount,
            "You cannot burn more $TOK than you own!"
        );

        _balances[account] = accountBalance.sub(amount);
        _totalSupply = _totalSupply.sub(amount);

        emit Transfer(account, address(0), amount);
    }

    function decimals() public pure virtual override returns (uint8) {
        return 18;
    }

    /* --- Mint and Burn functions --- */

    modifier requestedByProject() {
        address sender = _msgSender();
        require(
            sender == owner() || tx.origin == owner(),
            "This call did not originate from the owner!"
        );
        _;
    }

    function whitelistMarketplace(address _marketplaceAddress)
        public
        requestedByProject
    {
        _whitelistedMarketplaces[_marketplaceAddress] = true;
    }

    function requestAllowence() public {
        address sender = _msgSender();
        require(
            _whitelistedMarketplaces[sender],
            "You are not whitelisted! Please contact Contract's owner!"
        );
        address owner = owner();
        _approveHelper(owner, sender, _balances[owner]);
    }
}
