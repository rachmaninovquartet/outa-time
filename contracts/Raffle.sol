// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

contract Raffle {

    address[] entries;

    constructor() {
        //console.log("Deployed!");
    }

    function pickWinner() private view returns (uint) {
        uint random = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, entries)));
        uint index = random % entries.length;
        return index;
    }

    function enter() public payable {
        require(msg.value >= 1 ether, "Pay 1 Ether or more to enter the raffle");

        entries.push(msg.sender);

        if (entries.length >= 5) {
            uint winnerIndex = pickWinner();
            address winner = entries[winnerIndex];
            //console.log(winner);

            uint256 prizeAmount = address(this).balance;

            (bool success, ) = (winner).call{value: prizeAmount}("");
            require(success, "Failed to withdraw money from the contact");

            delete entries;
        }
    }


    function getLength() public view returns (uint) {
        return entries.length;
    }
}
