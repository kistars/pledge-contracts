# Pledge contract:
实现了一个借贷合约。

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```
``` javascript
let multiSignatureAddress = "0xC668eaC0c78E1c91CafCDeeA05dD04eD02bFA239";
let debtTokenAddress = "0x44Ec8be17246648752F6108c91161fF122F5dA8c";
let oracleAddress = "0x89b2eE05A49becA778A39c996772f72a3Cd27ff5";
let WETH9Address = "0xb06382Aa6e09863543f1f502DFe4509996e86B11";
let UniSwapRouter = "0x440B30001963F144EE95Cd7Fc7405090a0A0e00c";
let UniSwapFactory  = "0x140F5150F66110De2242E2735361ff1b192261d8";

let PlegdePoolAddress = "0x140F5150F66110De2242E2735361ff1b192261d8";
```