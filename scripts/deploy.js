const hre = require("hardhat")


async function main() {
    // Chain dependent variables
    const networkName = hre.network.name
    let desiredGasPrice, saleWalletAddress, stakingRewardWalletAddress
    let feeCollectorAddresses = []
    if (networkName == "goerli") {
        desiredGasPrice = 1
        feeCollectorAddresses = [
            "0x0000000000000000000000000000000000000001",
            "0x0000000000000000000000000000000000000002",
            "0x0000000000000000000000000000000000000003",
            "0x0000000000000000000000000000000000000004"
        ]
        saleWalletAddress = "0x49A61ba8E25FBd58cE9B30E1276c4Eb41dD80a80"
        stakingRewardWalletAddress = "0x3edCe801a3f1851675e68589844B1b412EAc6B07"
    } else if (networkName == "bsc") {
        desiredGasPrice = 3
        feeCollectorAddresses = [
            "",
            "",
            "",
            ""
        ]
        saleWalletAddress = ""
        stakingRewardWalletAddress = ""
    }


    // Checking gas price
    await checkGasPrice(desiredGasPrice)
    console.log("Chain:", networkName)


    // Static constructor arguments
    const name = "Zars", symbol = "ZRS", decimals = "9"


    // Contracts
    // Deploying Zars
    const zarsContract = await hre.ethers.deployContract(
        "Zars",
        [name, symbol, decimals, feeCollectorAddresses, saleWalletAddress, stakingRewardWalletAddress]
    )
    await zarsContract.waitForDeployment()
    const zarsDeployTxHash = await zarsContract.deploymentTransaction().hash
    const zarsDeployTx = await hre.ethers.provider.getTransactionReceipt(zarsDeployTxHash)
    console.log("Zars deployed to:", zarsContract.target)
    console.log("at block number:", zarsDeployTx.blockNumber)

    // Deploying Airdrop
    const airdropContract = await hre.ethers.deployContract("Airdrop", [saleWalletAddress])
    await airdropContract.waitForDeployment()
    const airdropDeployTxHash = await airdropContract.deploymentTransaction().hash
    const airdropDeployTx = await hre.ethers.provider.getTransactionReceipt(airdropDeployTxHash)
    console.log("(Graph) Airdrop deployed to:", airdropContract.target)
    console.log("at block number:", airdropDeployTx.blockNumber)

    // Deploying Presale
    const presaleContract = await hre.ethers.deployContract("Presale", [saleWalletAddress])
    await presaleContract.waitForDeployment()
    const presaleDeployTxHash = await presaleContract.deploymentTransaction().hash
    const presaleDeployTx = await hre.ethers.provider.getTransactionReceipt(presaleDeployTxHash)
    console.log("(Graph) Presale deployed to:", presaleContract.target)
    console.log("at block number:", presaleDeployTx.blockNumber)

    // Deploying Staking
    const stakingContract = await hre.ethers.deployContract("Staking", [stakingRewardWalletAddress])
    await stakingContract.waitForDeployment()
    const stakingDeployTxHash = await stakingContract.deploymentTransaction().hash
    const stakingDeployTx = await hre.ethers.provider.getTransactionReceipt(stakingDeployTxHash)
    console.log("(Graph) Staking deployed to:", stakingContract.target)
    console.log("at block number:", stakingDeployTx.blockNumber)


    // Addresses
    const zarsAddress = zarsContract.target
    const airdropAddress = airdropContract.target
    const presaleAddress = presaleContract.target
    const stakingAddress = stakingContract.target
    // const zarsAddress = ""
    // const airdropAddress = ""
    // const presaleAddress = ""
    // const stakingAddress = ""


    // Verifying contracts
    await new Promise(resolve => setTimeout(resolve, 20000))
    await verify(zarsAddress, [name, symbol, decimals, feeCollectorAddresses, saleWalletAddress, stakingRewardWalletAddress])
    await verify(airdropAddress, [saleWalletAddress])
    await verify(presaleAddress, [saleWalletAddress])
    await verify(stakingAddress, [stakingRewardWalletAddress])


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
