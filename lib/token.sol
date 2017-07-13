pragma solidity ^0.4.12;

import "math.sol";
import "owned.sol";
import "migrable.sol";
import "src/dev_allocation.sol";

contract ERC20 {
    function totalSupply() constant returns (uint supply);
    function balanceOf( address who ) constant returns (uint value);
    function allowance( address owner, address spender ) constant returns (uint _allowance);

    function transfer( address to, uint value) returns (bool ok);
    function transferFrom( address from, address to, uint value) returns (bool ok);
    function approve( address spender, uint value ) returns (bool ok);

    event Transfer( address indexed from, address indexed to, uint value);
    event Approval( address indexed owner, address indexed spender, uint value);
}

contract TokenBase is ERC20, DSMath {
    uint256                                            _supply;
    mapping (address => uint256)                       _balances;
    mapping (address => mapping (address => uint256))  _approvals;

    function totalSupply() constant returns (uint256) {
        return _supply;
    }
    function balanceOf(address addr) constant returns (uint256) {
        return _balances[addr];
    }
    function allowance(address from, address to) constant returns (uint256) {
        return _approvals[from][to];
    }
    
    function transfer(address to, uint value) returns (bool) {
        assert(_balances[msg.sender] >= value);
        
        _balances[msg.sender] = sub(_balances[msg.sender], value);
        _balances[to] = add(_balances[to], value);
        
        Transfer(msg.sender, to, value);
        
        return true;
    }
    
    function transferFrom(address from, address to, uint value) returns (bool) {
        assert(_balances[from] >= value);
        assert(_approvals[from][msg.sender] >= value);
        
        _approvals[from][msg.sender] = sub(_approvals[from][msg.sender], value);
        _balances[from] = sub(_balances[from], value);
        _balances[to] = add(_balances[to], value);
        
        Transfer(from, to, value);
        
        return true;
    }
    
    function approve(address to, uint256 value) returns (bool) {
        _approvals[msg.sender][to] = value;
        
        Approval(msg.sender, to, value);
        
        return true;
    }
}

contract ProspectorsGoldToken is TokenBase, Owned, Migrable {
    string public constant name = "Prospectors Gold";
    string public constant symbol = "PGL";
    uint8 public constant decimals = 18;  // 18 decimal places, the same as ETH.

    address private game_address = 0xb1; // Address 0xb1 is provably non-transferrable. Game tokens will be moved to game platform after developing
    uint public constant game_allocation = 110000000 * WAD; // Base allocation of tokens owned by game (50%). Not saled tokens will be moved to game balance.
    uint public constant dev_allocation = 47500000 * WAD; //tokens allocated to prospectors team and developers (~21.6%)
    uint public constant crowdfunding_allocation = 60000000 * WAD; //tokens allocated to crowdsale (~27.2%)
    uint public constant bounty_allocation = 500000 * WAD; //tokens allocated to bounty program (~0.2%)
    uint public constant presale_allocation = 2000000 * WAD; //tokens allocated to very early investors (~0.9%)

    bool public locked = true; //token non transfarable yet. it can be unlocked after success crowdsale

    BountyProgram public bounty; //bounty tokens manager contract address
    ProspectorsCrowdsale public crowdsale; //crowdsale contract address
    ProspectorsDevAllocation public prospectors_dev_allocation; //prospectors team and developers tokens holder. Contract allows to get tokens in two periods (180 and 360 days)

    function ProspectorsGoldToken() {
        _supply = 220000000 * WAD;
        _balances[this] = _supply;
        mint_for(game_address, game_allocation);
    }
    
    //override and prevent transfer if crowdsale fails
    function transfer(address to, uint value) returns (bool)
    {
        if (locked == true && msg.sender != address(crowdsale)) revert();
        return super.transfer(to, value);
    }
    
    //override and prevent transfer if crowdsale fails
    function transferFrom(address from, address to, uint value)  returns (bool)
    {
        if (locked == true) revert();
        return super.transferFrom(from, to, value);
    }
    
    //unlock transfers if crowdsale success
    function unlock()
    {
        if (locked == true && crowdsale.is_success() == true)
        {
            locked = false;
        }
    }

    //create crowdsale contract and mint tokens for it
    function init_crowdsale(uint _standart_price, uint _bonus_price, uint _start_time, uint _end_time, address _dev_multisig) onlyOwner
    {
        if (address(0) != address(crowdsale)) revert();
        crowdsale = new ProspectorsCrowdsale(owner, _dev_multisig, game_address);
        mint_for(crowdsale, crowdfunding_allocation);
        crowdsale.init(10000000 * WAD, _standart_price, _bonus_price, _start_time, _end_time);
    }
    
    //create bounty manager contract and mint tokens for it. Allowed only if crowdsale success
    function init_bounty_program(BountyProgram _bounty) onlyOwner
    {
        if (address(0) != address(bounty) || locked == true) revert();
        bounty = _bounty;
        mint_for(bounty, bounty_allocation);
    }
    
    //create contract for holding dev tokens and mint tokens for it. Also mint tokens for very early investors. Allowed only if crowdsale success
    function init_dev_and_presale_allocation(address presale_token_address) onlyOwner
    {
        if (address(0) != address(prospectors_dev_allocation) || locked == true) revert();
        prospectors_dev_allocation = new ProspectorsDevAllocation(owner);
        mint_for(prospectors_dev_allocation, dev_allocation);
        mint_for(presale_token_address, presale_allocation);
    }
    
    //this function will be called after game release
    function clear_game_balance() onlyOwner
    {
        _supply = sub(_supply, _balances[game_address]);
        _balances[game_address] = 0;
    }
    
    //this code will be excluded from main net, using only in testnet
    function kill() onlyOwner
    {
        selfdestruct(owner);
    }
    
    //adding tokens to crowdsale, bounty, game and prospectors team
    function mint_for(address addr, uint amount) private
    {
        if (_balances[this] >= amount)
        {
            _balances[this] = sub(_balances[this], amount);
            _balances[addr] = add(_balances[addr], amount);
            Transfer(this, addr, amount);
        }
    }
}
