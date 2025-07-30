
const { ethers } = require("hardhat");

async function latestBlock() {
  const block = await ethers.provider.getBlock('latest');
  return ethers.BigNumber.from(block.number);
}

async function latestBlockNum() {
  const block = await ethers.provider.getBlock('latest');
  return block.number;
}

async function showBlock() {
  const block = await ethers.provider.getBlock('latest');
  console.log("Block number: " + block.number.toString());
}

async function showBlock(msg) {
  const block = await ethers.provider.getBlock('latest');
  console.log(msg + " at block number: " + block.number.toString());
}

async function stopAutoMine() {
  //stop auto mine or it will mess the block number
  await ethers.provider.send("evm_setIntervalMining", [600000])
  // await ethers.provider.send("evm_setAutomine", [false])
}

function advanceBlock() {
  // return ethers.provider.send("evm_mine", [new Date().getTime()])
  return ethers.provider.send("evm_mine", [])
}

// Advance the block to the passed height
async function advanceBlockTo(target) {
  // stop interval mint,set to 600s
  await stopAutoMine()
  if (!ethers.BigNumber.isBigNumber(target)) {
    target = ethers.BigNumber.from(target);
  }

  const currentBlock = await latestBlock();
  const start = Date.now();
  let notified;
  if (target.lt(currentBlock)) throw Error(`Target block #(${target}) is lower than current block #(${currentBlock})`);
  while ((await latestBlock()).lt(target)) {
    if (!notified && Date.now() - start >= 5000) {
      notified = true;
      console.log(`\
@openzeppelin/test-helpers WARN advanceBlockTo: Advancing too ` +
        'many blocks is causing this test to be slow.');
    }
    await advanceBlock();
  }
  await showBlock('arrive')
}

// Returns the time of the last mined block in seconds
async function latest() {
  const block = await ethers.provider.getBlock('latest');
  return ethers.BigNumber.from(block.timestamp);
}

async function increase(seconds) {
  await ethers.provider.send("evm_increaseTime", [seconds])
  await advanceBlock();
}

module.exports = {
  advanceBlockTo,
  advanceBlock,
  latestBlock,
  latestBlockNum,
  showBlock,
  stopAutoMine,
  latest,
  increase
};