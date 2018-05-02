pragma solidity ^0.4.12;


contract IMigrationContract {
    function migrate(address _addr, uint256 _value) returns (bool success);
}


library SafeMath {

    function sub(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


contract Token {
    uint256 public totalSupply;

    function balanceOf(address _owner) constant returns (uint256 balance);
    function transfer(address _to, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);
    function approve(address _spender, uint256 _value) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}


/*  ERC 20 token */
contract StandardToken is Token {

    using SafeMath for uint256;

    function transfer(address _to, uint256 _value) returns (bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool) {
        var _allowance = allowed[_from][msg.sender];

        // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
        // require (_value <= _allowance);

        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool) {

        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    mapping (address => uint256) balances;

    mapping (address => mapping (address => uint256)) allowed;
}


contract HmsToken is StandardToken {
    string  public constant name = "Hms Token";
    string  public constant symbol = "HMC";
    uint256 public constant decimals = 18;
    string  public          version = "1.0.0";

    address public treasury;                // owner of hmc team.
    address public newContractAddr;         // the new contract for hmc token updates;

    uint256 public currentSupply;           // current supply tokens for sell
    uint256 public hmcRaised = 0;           // the number of total sold hmc
    uint256 public hmcMigrated = 0;         // the number of total transferred hmc

    // events
    event DistributeHmc(address indexed _to, uint256 _value);   // distribute hmc for private sale;
    event PayEvent(address indexed _to, uint256 _value);      // pay event;
    event IncreaseSupply(uint256 _value);
    event DecreaseSupply(uint256 _value);
    event Migrate2NewContract(address indexed _to, uint256 _value);

    // format decimals.
    function formatDecimals(uint256 _value) internal returns (uint256) {
        return _value * 10 ** decimals;
    }

    // constructor
    function HmsToken() {
        treasury = msg.sender;
        currentSupply = formatDecimals(400000000);
        totalSupply = formatDecimals(1000000000);
    }

    modifier isOwner()  {require(msg.sender == treasury);_;}

    // increase the token's supply
    function increaseSupply(uint256 _value) isOwner external {
        uint256 value = formatDecimals(_value);
        if (value + currentSupply > totalSupply) revert();
        currentSupply = currentSupply.add(value);
        IncreaseSupply(value);
    }

    // decrease the token's supply
    function decreaseSupply(uint256 _value) isOwner external {
        uint256 value = formatDecimals(_value);
        if (value + hmcRaised > currentSupply) revert();
        currentSupply = currentSupply.sub(value);
        DecreaseSupply(value);
    }

    // set a new contract for update contract
    function setMigrateContract(address _newContractAddr) isOwner external {
        if (_newContractAddr == newContractAddr) revert();
        newContractAddr = _newContractAddr;
    }

    // set a new owner.
    function changeOwner(address _newTreasury) isOwner external {
        if (_newTreasury == address(0x0)) revert();
        treasury = _newTreasury;
    }

    // sends the hmc to new contract
    function migrate2NewContract() external {
        if (newContractAddr == address(0x0)) revert();

        uint256 tokens = balances[msg.sender];
        if (tokens == 0) revert();

        balances[msg.sender] = 0;
        hmcMigrated = hmcMigrated.add(tokens);

        IMigrationContract newContract = IMigrationContract(newContractAddr);
        if (!newContract.migrate(msg.sender, tokens)) revert();

        Migrate2NewContract(msg.sender, tokens);
    }

    // sends ETH to hms team
    function depositETH() isOwner external {
        if (this.balance == 0) revert();
        treasury.transfer(this.balance);
    }

    // distribute hmc to pre-sell address.
    function distributeHmc(address _addr, uint256 _value) isOwner external {
        if (_value == 0) revert();
        if (_addr == address(0x0)) revert();

        uint256 tokens = formatDecimals(_value);
        if (tokens + hmcRaised > currentSupply) revert();

        hmcRaised = hmcRaised.add(tokens);
        balances[_addr] = balances[_addr].add(tokens);

        DistributeHmc(_addr, tokens);
    }

    // buys the hmc get nothing
    function() payable external {
        if (msg.value == 0) revert();
        PayEvent(msg.sender, msg.value);
    }
}
