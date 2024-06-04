#!/bin/bash
set -euxo pipefail

if [ $# -ne 1 ]
then
  >&2 echo "USAGE: ./install_staging.sh SSH_DESTINATION"
  exit 1
fi

if ! command -v btcli
then
  >&2 echo "ERROR: please install btcli: https://github.com/opentensor/bittensor?tab=readme-ov-file#install"
  exit 1
fi


SSH_DESTINATION="$1"
: "${OWNER_WALLET_NAME:=owner}"
: "${VALIDATOR_WALLET_NAME:=validator}"
: "${MINER_WALLET_NAME:=miner}"
: "${WALLETS_DIR:=$HOME/.bittensor/wallets}"

# set up wallets
if [ ! -e ${WALLETS_DIR}/$OWNER_WALLET_NAME ]
then
  echo "Creating wallet for owner: $OWNER_WALLET_NAME"
  btcli wallet new_coldkey --wallet.name "$OWNER_WALLET_NAME" --no_password --no_prompt
fi

if [ ! -e "$WALLETS_DIR/$VALIDATOR_WALLET_NAME" ]
then
  echo "Creating wallet for validator: $VALIDATOR_WALLET_NAME"
  btcli wallet new_coldkey --wallet.name "$VALIDATOR_WALLET_NAME" --no_password --no_prompt
  btcli wallet new_hotkey --wallet.name "$VALIDATOR_WALLET_NAME" --wallet.hotkey default --no_prompt
fi

if [ ! -e "$WALLETS_DIR/$MINER_WALLET_NAME" ]
then
  echo "Creating wallet for miner: $MINER_WALLET_NAME"
  btcli wallet new_coldkey --wallet.name "$MINER_WALLET_NAME" --no_password --no_prompt
  btcli wallet new_hotkey --wallet.name "$MINER_WALLET_NAME" --wallet.hotkey default --no_prompt
fi

BT_DEFAULT_TOKEN_WALLET=$(cat "$WALLETS_DIR/$OWNER_WALLET_NAME/coldkeypub.txt" | python3 -c 'import sys, json; print(json.load(sys.stdin)["ss58Address"])')


echo "Installing docker in the server..."

ssh "$SSH_DESTINATION" <<'ENDSSH'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# install docker
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
do
  (yes | sudo apt-get remove $pkg) || true
done

sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-compose-plugin
sudo usermod -aG docker $USER
ENDSSH


echo "Starting subtensor in the server..."

ssh "$SSH_DESTINATION" <<ENDSSH
set -euo pipefail

cat > docker-compose.yml <<'ENDDOCKERCOMPOSE'
version: '3.7'
services:
  subtensor:
    image: backenddevelopersltd/compute-horde-local-subtensor:v0-latest
    restart: unless-stopped
    volumes:
      - "./chain/alice:/tmp/alice"
      - "./chain/bob:/tmp/bob"
      - "./chain/spec:/spec"
      - "~/.bittensor:/root/.bittensor"
    ports:
      - "30334:30334"
      - "9946:9946"
      - "9934:9934"
    environment:
      - BT_DEFAULT_TOKEN_WALLET=$BT_DEFAULT_TOKEN_WALLET
ENDDOCKERCOMPOSE

docker compose pull
docker compose up -d --force-recreate
ENDSSH

echo "Waiting for subtensor to start..."
sleep 20


CHAIN_ENDPOINT=ws://$(ssh -G "$SSH_DESTINATION" | grep '^hostname' | cut -d' ' -f2):9946
echo ">> subtensor installed, chain endpoint: $CHAIN_ENDPOINT"

btcli subnet create --wallet.name "$OWNER_WALLET_NAME" --wallet.hotkey default --subtensor.chain_endpoint "$CHAIN_ENDPOINT" --no_prompt

# Transfer tokens to miner and validator coldkeys
export BT_MINER_TOKEN_WALLET=$(cat "$WALLETS_DIR/$MINER_WALLET_NAME/coldkeypub.txt" | python3 -c 'import sys, json; print(json.load(sys.stdin)["ss58Address"])')
export BT_VALIDATOR_TOKEN_WALLET=$(cat "$WALLETS_DIR/$VALIDATOR_WALLET_NAME/coldkeypub.txt" | python3 -c 'import sys, json; print(json.load(sys.stdin)["ss58Address"])')

btcli wallet transfer --subtensor.network "$CHAIN_ENDPOINT" --wallet.name "$OWNER_WALLET_NAME" --dest "$BT_MINER_TOKEN_WALLET" --amount 1000 --no_prompt
btcli wallet transfer --subtensor.network "$CHAIN_ENDPOINT" --wallet.name "$OWNER_WALLET_NAME" --dest "$BT_VALIDATOR_TOKEN_WALLET" --amount 10000 --no_prompt

# btcli wallet faucet --subtensor.network "$CHAIN_ENDPOINT" --wallet.name "$MINER_WALLET_NAME" --no_prompt
# btcli wallet faucet --subtensor.network "$CHAIN_ENDPOINT" --wallet.name "$VALIDATOR_WALLET_NAME" --no_prompt

# Register wallet hotkeys to subnet
btcli subnet register --wallet.name "$MINER_WALLET_NAME" --netuid 1 --wallet.hotkey default --subtensor.chain_endpoint "$CHAIN_ENDPOINT" --no_prompt
btcli subnet register --wallet.name "$VALIDATOR_WALLET_NAME" --netuid 1 --wallet.hotkey default --subtensor.chain_endpoint "$CHAIN_ENDPOINT" --no_prompt

# Add stake to the validator
btcli stake add --wallet.name "$VALIDATOR_WALLET_NAME" --wallet.hotkey default --subtensor.chain_endpoint "$CHAIN_ENDPOINT" --amount 100 --no_prompt

# Set root weight
# btcli root register --wallet.name "$VALIDATOR_WALLET_NAME" --wallet.hotkey default --subtensor.chain_endpoint "$CHAIN_ENDPOINT" --no_prompt
# btcli root boost --netuid 1 --increase 1 --wallet.name "$VALIDATOR_WALLET_NAME" --wallet.hotkey default --subtensor.chain_endpoint "$CHAIN_ENDPOINT" --no_prompt
