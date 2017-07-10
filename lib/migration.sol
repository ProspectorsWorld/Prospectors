pragma solidity ^0.4.12;

import "lib/token.sol";

contract Migrable is TokenBase
{
    event Migrate(address indexed _from, address indexed _to, uint256 _value);
    address public migrationMaster;
    address public migrationAgent;
    uint256 public totalMigrated;

    function Migrable() {
        migrationMaster = msg.sender;
    }

    function migrate(uint256 _value) external {
        // Abort if not in Operational Migration state.
        if (migrationAgent == 0)  revert();
        if (_value == 0)  revert();
        if (_value > _balances[msg.sender])  revert();

        _balances[msg.sender] -= _value;
        _supply -= _value;
        totalMigrated += _value;
        MigrationAgent(migrationAgent).migrateFrom(msg.sender, _value);
        Migrate(msg.sender, migrationAgent, _value);
    }

    function setMigrationAgent(address _agent) external {
        if (migrationAgent != 0)  revert();
        if (msg.sender != migrationMaster)  revert();
        migrationAgent = _agent;
    }

    function setMigrationMaster(address _master) external {
        if (msg.sender != migrationMaster)  revert();
        if (_master == 0)  revert();
        migrationMaster = _master;
    }
}

contract MigrationAgent {
    function migrateFrom(address _from, uint256 _value);
}

