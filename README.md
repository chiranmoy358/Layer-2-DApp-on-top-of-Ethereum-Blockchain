# Layer-2-DApp-on-top-of-Ethereum-Blockchian

Steps to execute:

1. Run "truffle init" in a terminal, some files and folders will be generated
2. Move client.py to the base directory, where "truffle init" was executed
3. Move Payment.sol to the generated contracts folder
4. Run ganache in terminal or use GUI, to simulate a local blockchain
5. [Needed if ganache cli is used] Uncomment line 67 to 71 in truffle-config.js
5. Run "truffle migrate" to deploy the Smart Contract to the local blockchain
6. Run client.py to register users, create joint accounts and fire the transactions.

The result of the simulation is printed in stdout.
