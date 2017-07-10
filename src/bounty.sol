pragma solidity ^0.4.12;

import "lib/token.sol";
import "lib/owned.sol";
import "lib/math.sol";

contract BountyProgram is Owned, DSMath
{
    mapping(bytes32 => uint) public reward_balances;
    mapping(bytes32 => uint) public total_bounty_type_tokens;
    mapping(bytes32 => mapping(address => uint)) public user_balances;
    mapping(address => bool) public claimed;
    
    bool private finalized = false;
    
    bytes32[4] public bounty_types;
    ProspectorsGoldToken private token;
    
    function BountyProgram(address _owner, ProspectorsGoldToken _token, bytes32[4] _bounty_types, uint80[4] rewards)
    {
        token = _token;
        bounty_types = _bounty_types;
        owner = _owner;
        for(uint8 i = 0; i < bounty_types.length; i++)
    	{
    	    reward_balances[bounty_types[i]] = rewards[i];
    	}
    }
    
    function add_to_user_balance(bytes32 bounty_type, address wallet_address, uint amount) onlyOwner
    {
        if (finalized == true || amount <= 0)  revert();
        user_balances[bounty_type][wallet_address] += amount;
        total_bounty_type_tokens[bounty_type] += amount;
    }
    
    function remove_from_user_balance(bytes32 bounty_type, address wallet_address, uint amount) onlyOwner
    {
        if (finalized == true || amount <= 0 || user_balances[bounty_type][wallet_address] < amount)  revert();
        user_balances[bounty_type][wallet_address] -= amount;
        total_bounty_type_tokens[bounty_type] -= amount;
    }
    
    function finalize() onlyOwner
    {
        finalized = true;
    }
    
    function claim()
    {
        if (finalized == false || claimed[msg.sender] == true) revert();
        claimed[msg.sender] = true;
        token.transfer(msg.sender, calculate_for_sender());
    }

    function calculate_for_sender() private returns (uint)
    {
        uint amount = 0;
        
        for(uint8 i = 0; i < bounty_types.length; i++)
    	{
    	    if (total_bounty_type_tokens[bounty_types[i]] > 0)
    	    {
        	    var bounty_type = bounty_types[i];
        	    var price = wdiv(cast(reward_balances[bounty_type]), cast(total_bounty_type_tokens[bounty_type]));
        	    amount += wmul(cast(price), cast(user_balances[bounty_types[i]][msg.sender]));
    	    }
    	}
    	
    	return amount;
    }
}
