const hre = require("hardhat")


async function main() {
    // Checking gas price
    let desiredGasPrice = 10
    await checkGasPrice(desiredGasPrice)


    // Addresses
    const tokenAddress = "0x0B855F1051a4a5011bCCa92E4cBb0A9494f95009"
    const airdropAddress = "0xf1C33B75728F1bf30128B92010bD0D9E1038b273"


    // Verifying contracts
    await new Promise(resolve => setTimeout(resolve, 20000))
    await verify(tokenAddress, [, , ])
    await verify(airdropAddress, [])


    process.exit()
}


async function checkGasPrice(desiredGasPrice) {
    let feeData = await hre.ethers.provider.getFeeData()
    let gasPrice = hre.ethers.formatUnits(feeData.gasPrice, "gwei")
    console.log("Gas Price:", gasPrice, "Gwei")
    while (gasPrice > desiredGasPrice) {
        feeData = await hre.ethers.provider.getFeeData()
        gasPrice = hre.ethers.formatUnits(feeData.gasPrice, "gwei")
        console.log("Gas Price:", gasPrice, "Gwei")
    }
}


async function verify(address, constructorArguments) {
    console.log(`verify ${address} with arguments ${constructorArguments.join(",")}`)
    try {  
        await hre.run("verify:verify", {
            address,
            constructorArguments
        })
    } catch(error) { console.log(error) }
}


main().catch((error) => {
    console.error(error)
    process.exitCode = 1
    process.exit()
})
