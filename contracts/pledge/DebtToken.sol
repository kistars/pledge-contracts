// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./AddressPrivileges.sol";

contract DebtToken is ERC20, AddressPrivileges {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) AddressPrivileges(msg.sender) {}

    function mint(address _to, uint256 _amount) public onlyMinter returns (bool) {
        _mint(_to, _amount);
        return true;
    }

    function burn(address _from, uint256 _amount) public onlyMinter returns (bool) {
        _burn(_from, _amount);
        return true;
    }
}
