pragma solidity ^0.4.12;

import "math.sol";
import "owned.sol";

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
    string public constant name = "ProspectorsGoldToken";
    string public constant symbol = "PGT";
    uint8 public constant decimals = 18;  // 18 decimal places, the same as ETH.

    uint public constant game_allocation = 11000000 ether;
    uint public dev_allocation = 50000000 ether;
    uint public crowdfunding_allocation = 50000 ether;
    uint public bounty_allocation = 500000 ether;
    
    
    BountyProgram public bounty;
    ProspectorsCrowdsale public crowdsale;
    
    function ProspectorsGoldToken() {
        _supply = 220000000 ether; 
    }
    
    function init_crowdsale() onlyOwner
    {
        if (address(0) != address(crowdsale)) revert();
        crowdsale = new ProspectorsCrowdsale(owner);
        _balances[crowdsale] = crowdfunding_allocation;
        crowdsale.init(5000 ether, 0.001 ether, 0.0005 ether, block.timestamp, block.timestamp + 5 minutes);
    }
    
    function init_bounty_program(BountyProgram _bounty) onlyOwner
    {
        if (address(0) != address(bounty)) revert();
        bounty = _bounty;
        _balances[bounty] = bounty_allocation;
    }
}

