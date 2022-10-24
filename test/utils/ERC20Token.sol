// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import "solmate/tokens/ERC20.sol";

contract ERC20Token is ERC20("ERC20", "ERC", 18) {
    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
