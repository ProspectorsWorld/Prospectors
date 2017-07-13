pragma solidity ^0.4.12;

import "lib/token.sol";
import "lib/owned.sol";
import "lib/math.sol";

contract ProspectorsCrowdsale is Owned, DSMath
{
    ProspectorsGoldToken public token;
    
    uint public start_time;
    uint public end_time;
    uint public bonus_amount;
    uint public start_amount;
    uint public price;
    uint public bonus_price;
    uint public total_raised;
    
    uint private constant goal = 2000 ether;
    bool private closed = false;
    
    address private address_for_not_saled_tokens;
    
    mapping(address => uint) funded;
    
    modifier in_time
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
    
    modifier has_value
    {
        if (msg.value <= 0) revert();
        _;
    }

    function ProspectorsCrowdsale(address _owner, address _address_for_not_saled_tokens)
    {
        token = ProspectorsGoldToken(msg.sender);
        address_for_not_saled_tokens = _address_for_not_saled_tokens;
        owner = _owner;
    }

    function init(uint256 _bonus_amount, uint256 _price, uint256 _bonus_price, uint _start_time, uint _end_time)
    {
        if (msg.sender != address(token) || _start_time < time() || _bonus_amount > my_token_balance()) revert();
        bonus_amount = _bonus_amount;
        bonus_price = _bonus_price;
        price = _price;
        start_time = _start_time;
        end_time = _end_time;
        start_amount = my_token_balance(); 
    }
    
    function buy() in_time has_value private {
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
                    token.transfer(address_for_not_saled_tokens, my_token_balance()); //move not saled tokens to game balance
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
        owner.transfer(this.balance);
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

    //this code will be excluded from mainnet, using only in testnet
    function kill() onlyOwner
    {
        selfdestruct(owner);
    }
}
