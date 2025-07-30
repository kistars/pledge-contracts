// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

const { ethers } = require("hardhat");
let multiSignatureAddress = "0xC668eaC0c78E1c91CafCDeeA05dD04eD02bFA239";

async function main() {

  // const [deployerMax,,,,deployerMin] = await ethers.getSigners();
  const [deployerMin, , , , deployerMax] = await ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    deployerMin.address
  );

  console.log("Account balance:", (await ethers.provider.getBalance(deployerMin.address)).toString());

  const oracleToken = await ethers.getContractFactory("BscPledgeOracle");
  const oracle = await oracleToken.connect(deployerMin).deploy(multiSignatureAddress);
  await oracle.waitForDeployment();

  console.log("Oracle address:", oracle.target);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });