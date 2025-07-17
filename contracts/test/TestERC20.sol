// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract TestERC20 is ERC20, ERC20Permit {

    constructor() ERC20("TestERC20", "T20") ERC20Permit("TestERC20") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }
}