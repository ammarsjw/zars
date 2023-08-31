const hre = require("hardhat")


async function main() {
    // Checking gas price
    let desiredGasPrice = 1
    await checkGasPrice(desiredGasPrice)


    // Protocol addresses and initialization addresses
    const zarsAddress = "0x2bB0b32eFaB2858AbF2744D94c20D9F07A4f0478"
    const airdropAddress = "0x0Ae3BD671cA5A5CC026Cf2deb84Ff19ED459773f"
    const presaleAddress = "0xbb32CFBCBFd54449Cc5a7Fe7514A9CE15541c0b4"
    const stakingAddress = "0x1a63958835e3818557f0875fecD5064102dA1462"


    // Contracts
    // Initializing Airdrop
    const airdropInstance = await hre.ethers.getContractAt("Airdrop", airdropAddress)
    await airdropInstance.initialize(zarsAddress, stakingAddress)
    console.log("Airdrop initialized")

    // Initializing Presale
    const presaleInstance = await hre.ethers.getContractAt("Presale", presaleAddress)
    await presaleInstance.initialize(zarsAddress, stakingAddress)
    console.log("Presale initialized")

    // Initializing Staking
    const stakingInstance = await hre.ethers.getContractAt("Staking", stakingAddress)
    await stakingInstance.initialize(zarsAddress, airdropAddress, presaleAddress)
    console.log("Staking initialized")


    // Staging only
    const [, saleWallet, stakingRewardWallet] = await hre.ethers.getSigners()
    const zarsInstance = await hre.ethers.getContractAt("Zars", zarsAddress)
    // const uintMax = (2 ** 256) - 1
    const uintMax = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
    await zarsInstance.connect(saleWallet).approve(airdropAddress, uintMax)
    console.log("Sale wallet's allowance granted to Airdrop")
    await zarsInstance.connect(saleWallet).approve(presaleAddress, uintMax)
    console.log("Sale wallet's allowance granted to Presale")
    await zarsInstance.connect(stakingRewardWallet).approve(stakingAddress, uintMax)
    console.log("staking reward wallet's allowance granted to Staking")


    process.exit()
}


async function checkGasPrice(desiredGasPrice) {
    let feeData = await hre.ethers.provider.getFeeData()
    let gasPrice = hre.ethers.formatUnits(feeData.gasPrice, "gwei")
    console.log("Gas Price:", gasPrice, "Gwei")
    while (gasPrice > desiredGasPrice) {
        feeData = await hre.ethers.provider.getFeeData()
        if (gasPrice != hre.ethers.formatUnits(feeData.gasPrice, "gwei")) {
            gasPrice = hre.ethers.formatUnits(feeData.gasPrice, "gwei")
            console.log("Gas Price:", gasPrice, "Gwei")
        }
    }
}


main().catch((error) => {
    console.error(error)
    process.exitCode = 1
    process.exit()
})
