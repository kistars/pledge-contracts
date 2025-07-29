const { ethers } = require("hardhat");

let multiSignatureAddress = ["0x74eDf70e292bA5b835FAf90a164e02357a92FC89",
  "0x57940AD69265f7B705045a4e05043f3F70F85802",
  "0x8f12753dA494299DB201d8AA6A1660528e9E498c"];
let threshold = 2;


async function main() {

  const [deployerMax, deployerMin] = await ethers.getSigners(); // 由配置文件中的accounts字段决定

  console.log(
    "Deploying contracts with the account:",
    deployerMax.address, " ==== ", deployerMin.address
  );

  console.log("Account balance:", (await ethers.provider.getBalance(deployerMax.address)).toString());

  const multiSignatureToken = await ethers.getContractFactory("multiSignature");
  const multiSignature = await multiSignatureToken.connect(deployerMax).deploy(multiSignatureAddress, threshold);
  await multiSignature.waitForDeployment();

  console.log("multiSignature address:", multiSignature.target);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });