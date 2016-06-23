// A contract that takes deposits of ether and issues equal numbers of 'noFork' 
// Tokens and 'fork' Tokens. These are tradable but only one can be turned 
// back into ether after block 1900000 ether depending on whether the fork goes through.

// a basic token interface
contract Token {

    /// @return total amount of tokens
    function totalSupply() constant returns (uint256 supply) {}

    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) constant returns (uint256 balance) {}

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _value) returns (bool success) {}

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {}

    /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of wei to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _value) returns (bool success) {}

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {}

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}


///a standard token contract
contract StandardToken is Token {

    function transfer(address _to, uint256 _value) returns (bool success) {
        //Default assumes totalSupply can't be over max (2^256 - 1).
        //If your token leaves out totalSupply and can issue more tokens as time goes on, you need to check if it doesn't wrap.
        //Replace the if with this one instead.
        //if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        } else { return false; }
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        //same as above. Replace this line with the following if you want to protect against wrapping uints.
        //if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            Transfer(_from, _to, _value);
            return true;
        } else { return false; }
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    uint256 public totalSupply;
}
///A token which allows the issuing of new tokens and the destruction of old
contract ForkToken is StandardToken{

    //sets the token creator as its factory
    function ForkToken(){
        factory = TokenIssuer(msg.sender);
    }
    ///Creates new coins out of thin air when called by the tokenIssuer factory
    function issue(address _recip, uint amount){
        if (msg.sender != address(factory)) return;
        balances[_recip] += amount;
    }
    //burns tokens to reclaim ether - only works if the fork period has passed
    function burn(uint _amount){
        if (balances[msg.sender] < _amount) return;
        balances[msg.sender] -= _amount;
        if (factory.returnEther(_amount, msg.sender) == false) throw;
    }
    TokenIssuer factory;
}

/// A issuer contract which issues tokens when funded with ether and only refunds 
/// the 'winning' token after a certain date.
contract TokenIssuer {

    function TokenIssuer(){
        noFork = new ForkToken();
        fork = new ForkToken();
    }
    // issues noFork and fork tokens equal to the value of the ether deposited
    function issue(){
        noFork.issue(msg.sender,msg.value);
        fork.issue(msg.sender,msg.value);
    }
    // Get the code at a particular address. Code provided by @chriseth.
    // Review carefully.
    function at(address _addr) returns (bytes o_code) {
        assembly {
            // retrieve the size of the code, this needs assembly
            let size := extcodesize(_addr)
            // allocate output byte array - this could also be done without assembly
            // by using o_code = new bytes(size)
            o_code := mload(0x40)
            // new "memory end" including padding
            mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // store length in memory
            mstore(o_code, size)
            // actually retrieve the code, this needs assembly
            extcodecopy(_addr, add(o_code, 0x20), 0, size)
        }
    }
    ///checks if the fork has happened and if it has sets the bool forked to true
    function setFork() {
        if (
            // Check that TheDAO's code has been changed...
            sha3(at(0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413)) != 0x7278d050619a624f84f51987149ddb439cdaadfba5966f7cfaea7ad44340a4ba
            ) 
        {forked = true;}
    }
    ///returns ether if called by the correct token contract
    function returnEther(uint _amount, address _recip) returns (bool){
        //is past a certain date
        if (block.number < 1900000) return false;
        if (forked == true && msg.sender == address(fork))
        {
            _recip.send(_amount);
            return true;
        }
        else if (forked == false && msg.sender == address(noFork))
        {
            _recip.send(_amount);
            return true;
        }
        else return false;
    }
    
    bool forked;
    ForkToken noFork;
    ForkToken fork;
}
