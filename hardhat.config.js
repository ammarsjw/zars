require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
    solidity: {
        compilers: [
            {
                version: "0.8.21",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 999999,
                    },
                },
            },
        ],
    },
    networks: {
        goerli: {
            url: process.env.URL_GOERLI,
            accounts: [process.env.PRIVATE_KEY_GOERLI],
        },
        bsc: {
            url: process.env.URL_BSC,
            accounts: [process.env.PRIVATE_KEY_BSC],
        },
    },
    etherscan: {
        apiKey: "AYBZ53EN445WNPFP2IZ85RXRPB4FH5XBP7"
    },
};