pragma solidity ^0.4.12;
import "lib/token.sol";
import "lib/owned.sol";

contract ProspectorsDevAllocation is Owned
{
    ProspectorsGoldToken public token;
    uint private initial_time;
    uint private constant start_amount = 50000000 * 10**18;
    
    function ProspectorsDevAllocation(address _owner)
    {
        token = ProspectorsGoldToken(msg.sender);
        owner = _owner;
        initial_time = block.timestamp;
    }
    
    function unlock_first_part()
    {
        if (token.balanceOf(this) < start_amount || block.timestamp < initial_time + 180 days) revert();
        token.transfer(owner, 20000000 * 10**18);
    }
    
    function unlock_last_part()
    {
        if (token.balanceOf(this) == 0 || block.timestamp < initial_time + 360 days) revert();
        token.transfer(owner, token.balanceOf(this));
    }
    
    function kill() onlyOwner
    {
        if (token.balanceOf(this) != 0) revert();
        selfdestruct(owner);
    }
}
