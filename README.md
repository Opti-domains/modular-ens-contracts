## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ source .env && anvil --fork-url $FORK_URL
```

### Deploy

```shell
$ source .env && forge script script/DeployDev.s.sol:DeployDevScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Deploy to Optimism

```shell
$ source .env && forge script script/DeployDev.s.sol:DeployDevScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --optimize --verify --with-gas-price 10000000 --gas-price 10000000 --broadcast
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
