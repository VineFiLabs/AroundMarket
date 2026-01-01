// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    uint8 private thisDecimals;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 _thisDecimals
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        thisDecimals = _thisDecimals;
    }

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }

    function decimals() public override view returns (uint8) {
        return thisDecimals;
    }
}