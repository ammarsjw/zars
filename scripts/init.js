const hre = require("hardhat")

async function main() {
    // Chain dependent variables.
    const networkName = hre.network.name
    let desiredGasPrice

    if (networkName == "goerli") {
        desiredGasPrice = 1
    } else if (networkName == "bsc") {
        desiredGasPrice = 3
    }


    // Checking gas price.
    await checkGasPrice(desiredGasPrice)
    console.log("Chain:", networkName)


    // Protocol and initialization addresses.
    const zarsAddress = ""
    const airdropAddress = ""
    const presaleAddress = ""
    const stakingAddress = ""


    // Contracts.
    // Initializing Airdrop.
    const airdropInstance = await hre.ethers.getContractAt("Airdrop", airdropAddress)
    await airdropInstance.initialize(zarsAddress, stakingAddress)
    console.log("Airdrop initialized")

    // Initializing Presale.
    const presaleInstance = await hre.ethers.getContractAt("Presale", presaleAddress)
    await presaleInstance.initialize(zarsAddress, stakingAddress)
    console.log("Presale initialized")

    // Initializing Staking.
    const stakingInstance = await hre.ethers.getContractAt("Staking", stakingAddress)
    await stakingInstance.initialize(zarsAddress, airdropAddress, presaleAddress)
    console.log("Staking initialized")


    // Chain based secondary transactions.
    if (networkName == "goerli") {    
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
    } else if (networkName == "bsc") {
    }


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
