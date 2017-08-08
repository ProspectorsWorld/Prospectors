pragma solidity ^0.4.12;

import "lib/token.sol";

contract Migrable is TokenBase, Owned
{
    event Migrate(address indexed _from, address indexed _to, uint256 _value);
    address public migrationAgent;
    uint256 public totalMigrated;


    function migrate() external {
        migrate_participant(msg.sender);
    }
    
    function migrate_participant(address _participant) internal
    {
        // Abort if not in Operational Migration state.
        if (migrationAgent == 0)  revert();
        if (_balances[_participant] == 0)  revert();
        
        uint256 _value = _balances[_participant];
        _balances[_participant] = 0;
        _supply = sub(_supply, _value);
        totalMigrated = add(totalMigrated, _value);
        MigrationAgent(migrationAgent).migrateFrom(_participant, _value);
        Migrate(_participant, migrationAgent, _value);
        
    }

    function setMigrationAgent(address _agent) onlyOwner external {
        if (migrationAgent != 0)  revert();
        migrationAgent = _agent;
    }
}
