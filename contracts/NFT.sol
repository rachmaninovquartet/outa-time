// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFT is ERC721 {
	
	constructor(string memory name, string memory symbol) ERC721(name, symbol) {
	//TODO remove args and hard code name and symb?
        // do as little as possible in contructor https://medium.com/newcryptoblock/best-practices-in-solidity-b324b65d33b1
		
	}
}

