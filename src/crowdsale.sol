pragma solidity ^0.4.12;

import "lib/token.sol";
import "lib/owned.sol";
import "lib/math.sol";

contract ProspectorsCrowdsale is Owned, DSMath
{
    uint public start_time;
    uint public end_time;
    ProspectorsGoldToken public token;
    
    uint public bonus_amount;
    uint public start_amount;
    uint public price;
    uint public bonus_price;
    
    uint private total_raised;
    uint private to_return;
    uint private constant goal = 2 ether;
    bool private closed = false;
    
    mapping(address => Funder) funders;
    
    modifier in_time
    {
        if (time() < start_time || time() > end_time)  revert();
        _;
    }
    
    function total() public constant returns (uint)
    {
        return total_raised / 1 ether;
    }
    
    modifier has_value
    {
        if (msg.sender <= 0) revert();
        _;
    }
    
    struct Funder
    {
        uint amount;
        uint over_amount;
    }
    
    function time() public constant returns (uint)
    {
        return block.timestamp;
    }

    function ProspectorsCrowdsale(address _owner)
    {
        token = ProspectorsGoldToken(msg.sender);
        owner = _owner;
    }

    function init(uint _bonus_amount, uint _price, uint _bonus_price, uint _start_time, uint _end_time)
    {
        if (_start_time < time() || _bonus_amount > my_token_balance()) revert();
        bonus_amount = _bonus_amount;
        bonus_price = _bonus_price;
        price = _price;
        start_time = _start_time;
        end_time = _end_time;
        start_amount = my_token_balance(); 
    }
    
    function my_token_balance() constant returns (uint)
    {
        return token.balanceOf(this);
    }
    
    function available_with_bonus() constant returns (uint)
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
    
    function buy() in_time has_value private {
        if (my_token_balance() == 0 || closed == true) revert();

        var remains = msg.value;
        
        
         //calculate tokens amount by bonus price
        var can_with_bonus = wdiv(cast(remains), cast(bonus_price));
        var buy_amount = cast(min(can_with_bonus, available_with_bonus()));
        remains -= wmul(buy_amount, cast(bonus_price));
        
        if (buy_amount < can_with_bonus) //calculate tokens amount by standart price if tokens with bonus don't cover eth amount
        {
            var can_without_bonus = wdiv(cast(remains), cast(price));
            var buy_without_bonus = cast(min(can_without_bonus, available_without_bonus()));
            remains -= wmul(buy_without_bonus, cast(price));
            buy_amount += buy_without_bonus;
        }
        
        uint user_raised = msg.value - remains; 
        total_raised += user_raised;
        funders[msg.sender].amount += user_raised;
        
        
        
        if (remains > 0) //save superfluous balance to refund by user if tokens left are less then eth amount
        {
            funders[msg.sender].over_amount = remains;
            to_return = remains;
        }
        
        token.transfer(msg.sender, buy_amount); //transfer tokens to participant
    }
    
    function refund() //allows get eth back if min goal not reached
    {
        if (total_raised >= goal || closed == false) revert();
        var amount = funders[msg.sender].amount;
        if (amount > 0)
        {
            funders[msg.sender].amount = 0;
            msg.sender.transfer(amount);
        }
    }
    
    function refund_over_balance() //allows get superfluous eth back to last participant
    {
        if (my_token_balance() != 0 || closed == false) revert();
        var amount = funders[msg.sender].over_amount;
        if (amount > 0)
        {
            to_return -= amount;
            funders[msg.sender].over_amount = 0;
            msg.sender.transfer(amount);
        }
    }
    
    function closeCrowdsale() //unlock refunds
    {
        if (closed == false && time() > start_time && (time() > end_time || my_token_balance() == 0))
        {
            closed = true;
        }
        else
        {
            revert();
        }
    }
    
    function collect() //collect eth by devs if min goal reached
    {
        if (total_raised < goal) revert();
        uint amount = my_token_balance() == 0 ? this.balance - to_return : this.balance;
        owner.transfer(amount);
    }

    function () payable external {
        buy();
    }
    
    function destroy() onlyOwner
    {
        if (time() > end_time + 180 days)
        {
            selfdestruct(owner);
        }
    }
}
