const { ethers } = require("hardhat");
// const BN = web3.utils.BN;

async function mockUniswap(minter, weth) {
    const UniswapV2Factory = await ethers.getContractFactory("UniswapV2Factory");
    const uniswapFactory = await UniswapV2Factory.deploy(minter.address);
    await uniswapFactory.waitForDeployment();

    const UniswapV2Router02 = await ethers.getContractFactory("UniswapV2Router02");
    const uniswapRouter = await UniswapV2Router02.deploy(uniswapFactory.target, weth.target);
    await uniswapFactory.waitForDeployment();
    return [uniswapRouter, uniswapFactory]

}
// targetToken: {address: string, price: int}
async function mockAddLiquidity(router, token0, token1, minter, deadline, amount0, amount1) {
    // approve
    await token0.connect(minter).approve(router.target, BigInt(amount0));
    await token1.connect(minter).approve(router.target, BigInt(amount1));
    // add
    await router.connect(minter).addLiquidity(
        token0.target,
        token1.target,
        BigInt(amount0),
        BigInt(amount1),
        BigInt(0),
        BigInt(0),
        minter.address,
        deadline
    );
}

async function mockSwap(router, token0, swapAmount, minAmount, path, minter, deadline) {
    // approve
    await token0.connect(minter).approve(router.target, BigInt(swapAmount));
    // swap
    await router.connect(minter).swapExactTokensForTokens(
        BigInt(swapAmount),
        BigInt(minAmount),
        path,
        minter.address,
        deadline
    );
}


module.exports = {
    mockUniswap,
    mockSwap,
    mockAddLiquidity
};