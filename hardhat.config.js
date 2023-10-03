require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();


module.exports = {
    solidity: {
        compilers: [
            {
                version: "0.8.20",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1000000,
                    },
                },
            },
        ],
    },
    networks: {
        goerli: {
            url: process.env.URL_GOERLI,
            accounts: [
                process.env.PRIVATE_KEY_GOERLI,
                process.env.SALE_WALLET_PRIVATE_KEY_GOERLI,
                process.env.STAKING_REWARDS_WALLET_PRIVATE_KEY_GOERLI
            ],
        },
        bsc: {
            url: process.env.URL_BSC,
            accounts: [process.env.PRIVATE_KEY_BSC],
        },
    },
    etherscan: {
        apiKey: {
            goerli: process.env.BLOCK_EXPLORER_API_KEY_ETHEREUM,
            bsc: process.env.BLOCK_EXPLORER_API_KEY_BSC,
        },
    },
};
