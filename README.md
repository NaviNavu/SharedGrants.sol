# SharedGrants.sol

`☠️ THE CODE INCLUDED IN THIS REPOSITORY IS NOT BATTLE TESTED! USE IT AT YOUR OWN RISK ☠️`

This contract allows users to create Grants into which other users can deposit any amount of authorized 
ERC20 tokens that can then be claimed by a given beneficiary account when a defined timestamp is reached.
Users are given the option to instantly recover their token deposits during the grant period. 
At the end of the grant period, further deposits into the Grant are disabled and the Grant tokens are unlocked 
for the beneficiary account.


## Project setup and tests

Install Foundry on your machine by following the [FoundryBook](https://book.getfoundry.sh/getting-started/installation.html) recommandations. Then:

Clone this repo:
```bash
git clone https://github.com/NaviNavu/SharedGrants.sol.git
```

Head to the project root folder of the previoulsy cloned repo then build the project:
```bash
forge build
```

To run the tests:
```bash
forge test
```