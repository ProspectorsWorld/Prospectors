pragma solidity ^0.4.12;

import "lib/token.sol";
import "lib/owned.sol";
import "lib/math.sol";

contract ProspectorsCrowdsale is Owned, DSMath
{
    ProspectorsGoldToken public token;
    address public dev_multisig; //multisignature wallet to collect funds
    
    uint public total_raised; //crowdsale total funds raised
    uint public contributors_count = 0; //crowdsale total funds raised
    
    uint public constant start_time = 1502377200; //crowdsale start time - August 10, 15:00 UTC
    uint public constant end_time = 1505055600; //crowdsale end time - Septempber 10, 15:00 UTC
    uint public constant bonus_amount = 10000000 * 10**18; //amount of tokens by bonus price
    uint public constant start_amount = 60000000 * 10**18; //tokens amount allocated for crowdsale
    uint public constant price =  0.0005 * 10**18; //standart token price in ETH 
    uint public constant bonus_price = 0.0004 * 10**18; //bonus token price in ETH
    uint public constant goal = 2000 ether; //soft crowdsale cap. If not reached funds will be returned
    bool private closed = false; //can be true after end_time or when all tokens sold
    
    mapping(address => uint) funded; //needed to save amounts of ETH for refund
    
    modifier in_time //allows send eth only when crowdsale is active
    {
        if (time() < start_time || time() > end_time)  revert();
        _;
    }

    function is_success() public constant returns (bool)
    {
        return closed == true && total_raised >= goal;
    }
    
    function time() public constant returns (uint)
    {
        return block.timestamp;
    }
    
    function my_token_balance() public constant returns (uint)
    {
        return token.balanceOf(this);
    }
    
    //tokens amount available by bonus price
    function available_with_bonus() public constant returns (uint)
    {
        return my_token_balance() >=  min_balance_for_bonus() ? 
                my_token_balance() - min_balance_for_bonus() 
                : 
                0;
    }
    
    function available_without_bonus() private constant returns (uint)
    {
        return min(my_token_balance(),  min_balance_for_bonus());
    }
    
    function min_balance_for_bonus() private constant returns (uint)
    {
        return start_amount - bonus_amount;
    }
    
    //prevent send less than 0.01 ETH
    modifier has_value
    {
        if (msg.value < 0.01 ether) revert();
        _;
    }

    function init(address _token_address, address _dev_multisig) onlyOwner
    {
        if (address(0) != address(token)) revert();
        token = ProspectorsGoldToken(_token_address);
        dev_multisig = _dev_multisig;
    }
    
    //main contribute function
    function participate() in_time has_value private {
        if (my_token_balance() == 0 || closed == true) revert();

        var remains = msg.value;
        
         //calculate tokens amount by bonus price
        var can_with_bonus = wdiv(cast(remains), cast(bonus_price));
        var buy_amount = cast(min(can_with_bonus, available_with_bonus()));
        remains = sub(remains, wmul(buy_amount, cast(bonus_price)));
        
        if (buy_amount < can_with_bonus) //calculate tokens amount by standart price if tokens with bonus don't cover eth amount
        {
            var can_without_bonus = wdiv(cast(remains), cast(price));
            var buy_without_bonus = cast(min(can_without_bonus, available_without_bonus()));
            remains = sub(remains, wmul(buy_without_bonus, cast(price)));
            buy_amount = hadd(buy_amount, buy_without_bonus);
        }

        if (remains > 0) revert();

        total_raised = add(total_raised, msg.value);
        if (funded[msg.sender] == 0) contributors_count++;
        funded[msg.sender] = add(funded[msg.sender], msg.value);

        token.transfer(msg.sender, buy_amount); //transfer tokens to participant
    }
    
    function refund() //allows get eth back if min goal not reached
    {
        if (total_raised >= goal || closed == false) revert();
        var amount = funded[msg.sender];
        if (amount > 0)
        {
            funded[msg.sender] = 0;
            msg.sender.transfer(amount);
        }
    }
    
    function closeCrowdsale() //close crowdsale. this action unlocks refunds or token transfers
    {
        if (closed == false && time() > start_time && (time() > end_time || my_token_balance() == 0))
        {
            closed = true;
            if (is_success())
            {
                token.unlock(); //unlock token transfers
                if (my_token_balance() > 0)
                {
                    token.transfer(0xb1, my_token_balance()); //move not saled tokens to game balance
                }
            }
        }
        else
        {
            revert();
        }
    }
    
    function collect() //collect eth by devs if min goal reached
    {
        if (total_raised < goal) revert();
        dev_multisig.transfer(this.balance);
    }

    function () payable external 
    {
        participate();
    }
    
    //allows destroy this whithin 180 days after crowdsale ends
    function destroy() onlyOwner
    {
        if (time() > end_time + 180 days)
        {
            selfdestruct(dev_multisig);
        }
    }
}
