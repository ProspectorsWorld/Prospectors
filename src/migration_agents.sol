contract MigrationAgent {

    struct Migration {
        uint id;
        address participant;
        string eos_account_name;
        uint amount;
    }

    address game_address = 0xb1;
    address token_address = 0x9240ddc345d7084cc775eb65f91f7194dbbb48d8;
    uint public migration_id = 0;
    
    mapping(address => string) public registrations;
    mapping(address => Migration[]) public migrations;

    constructor(address ta) public {
        registrations[game_address] = "prospectors1";
        token_address = ta;
    }
    
    function migrateFrom(address participant, uint amount) public {
        if (msg.sender != token_address || !participantRegistered(participant)) revert();
        migrations[participant].push(Migration(migration_id, participant, registrations[participant], amount));
        migration_id++;
    }
    
    function register(string eos_account_name) public
    {
        registrations[msg.sender] = eos_account_name;
    }
    
    function participantRegistered(address participant) public constant returns (bool)
    {
        return keccak256(registrations[participant]) != keccak256("");
    }

}
