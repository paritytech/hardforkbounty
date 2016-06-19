/// hardforkbounty.sol
/// Copyright (c) Gav Wood 2016.
/// Licenced under Apache 2.

/// A bounty program for ensuring the DAO hard fork does through.
/// Everyone can put down a refundable deposit; miners can collect some fixed
/// proportion of the remaining deposit, once per block, only when the DAO has
/// had all funds returned and when the code has been changed (ideally we'll 
/// propose that change, too). If the bounty isn't paid (hard fork doesn't go
/// through) then deposits can be claimed once the block hits 1.9M.
contract HardForkBounty {
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

    /// Fallback function - this either deposits ether in the name of the
    /// message sender.
    function() {
        balances[msg.sender] += msg.value;
    }
    
    /// Claim function. Attempts to claim the bounty on behalf of the sender.
    /// Claiming the bounty may only be done once per block and results in the
    /// transfer of half of the remaining ether to the miner.
    function claim() {
        if (
            // Ensure that TheDAO's code has been changed...
            // TODO: ...to a known good contract e.g. WithdrawDAO.
            sha3(at(0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413)) != 0x7278d050619a624f84f51987149ddb439cdaadfba5966f7cfaea7ad44340a4ba &&
            // If it's the first reward claim, ensure that the stolen Ether has been put back in TheDAO.
            (address(0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413).balance > 11000000 ether || lastPayout > 0) &&
            // Ensure that this only happens once per block.
            now > lastPayout
        ) {
            // Record payout to avoid multiple claims on the same block.
            lastPayout = now;
            // Send back some proportion of the funds. A tenth for now.
            block.coinbase.send(this.balance / 10);
        }
    }
    
    /// Deposit function. Deposits ether on behalf of a third party.
    /// This is useful for people who only have exchange accounts.
    function deposit(address _who) {
        // Add the deposited ether to the account balance.
        balances[_who] += msg.value;
    }
    
    /// Withdraw ether. If the hard fork didn't go through, this allows bounty
    /// contributors to get their ether back. Once the block hits 1.9M, then
    /// it can be used. We assume that the hard fork has happened and the bounty
    /// paid by then, so there's no need for additional checks.
    function withdraw() {
        // Only if the block number is well-after hard-fork time:
        if (block.number > 1900000) {
            // Figure out how much we should be repaying (b).
            var b = balances[msg.sender];
            // Learn the lesson! Set to zero *and then* call send!
            balances[msg.sender] = 0;
            // Do the refund.
            msg.sender.send(b);
        }
    }
    
    mapping (address => uint) balances;
    uint lastPayout = 0;
}
