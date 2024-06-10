# bittensor devnet

## Install

Create an ubuntu server.
Make sure that port `9946` is open in your firewall.
Run the following command:
```shell
curl -sSfL https://raw.githubusercontent.com/backend-developers-ltd/bittensor-devnet/master/setup.sh | bash -s - SSH_DESTINATION
```

Replace `SSH_DESTINATION` with your server's connection info (i.e. `username@1.2.3.4`).

By default, this script will use `owner`, `validator` and `miner` as wallet names for owner, validator and miner respectively.
You can change that by setting the following variables:

```sh
export OWNER_WALLET_NAME=my-owner
export VALIDATOR_WALLET_NAME=my-validator
export MINER_WALLET_NAME=my-miner
```

The script will create the wallets if they are missing.

If your wallets are store somewhere other than `~/.bittensor/wallets`, you can specify with:

```sh
export WALLETS_DIR=/some/path/to/wallets/
```

After successful installation, the script will print the chain endpoint.
Use this chain endpoint in `btcli` commands and your test miners/validators.

**NOTE:** You have to export the variables *before* running the installation command.
The installation command have to be run in the same shell session (i.e. same terminal window).
