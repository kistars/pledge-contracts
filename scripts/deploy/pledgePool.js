// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

let oracleAddress = "0x89b2eE05A49becA778A39c996772f72a3Cd27ff5";
let swapRouter = "0x440B30001963F144EE95Cd7Fc7405090a0A0e00c";
let feeAddress = "0xa5D1E71aC4cE6336a70E8a0cb1B6DFa87BccEf4c"; // 手续费合约地址
let multiSignatureAddress = "0xC668eaC0c78E1c91CafCDeeA05dD04eD02bFA239";

const { ethers } = require("hardhat");

async function main() {

  // const [deployerMax,,,,deployerMin] = await ethers.getSigners();
  const [deployerMin, , , , deployerMax] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    deployerMin.address
  );

  console.log("Account balance:", (await ethers.provider.getBalance(deployerMin.address)).toString());

  const pledgePoolToken = await ethers.getContractFactory("PledgePool");
  const pledgeAddress = await pledgePoolToken.connect(deployerMin).deploy(oracleAddress, swapRouter, feeAddress, multiSignatureAddress);
  await pledgeAddress.waitForDeployment();

  console.log("pledgeAddress address:", pledgeAddress.target);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });