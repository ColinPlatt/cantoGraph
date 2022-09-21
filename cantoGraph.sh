#!/bin/bash

while true
do

# Logo

echo "=================================================================================================================================================="
curl -s https://raw.githubusercontent.com/ColinPlatt/cantoGraph/main/logo.sh | bash
echo "=================================================================================================================================================="

# Menu

PS3='Select an action: '
options=(
"Install Graph Node"
"Check Log"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install Graph Node")
echo "============================================================"
echo "Install start"
echo "============================================================"
echo "Setup RPC URL:"
echo "============================================================"
read RPC_URL
echo "============================================================"
echo "Name db:"
echo "============================================================"
read DB_NAME
echo "db username:"
echo "============================================================"
read DB_USER
echo "db password:"
echo "============================================================"
read DB_USER_PASS


echo export RPC_URL=${RPC_URL} >> $HOME/.bash_profile
echo export DB_NAME=${DB_NAME} >> $HOME/.bash_profile
echo export DB_USER=${DB_USER} >> $HOME/.bash_profile
echo export DB_USER_PASS=${DB_USER_PASS} >> $HOME/.bash_profile
source ~/.bash_profile

#UPDATE APT -hold for testing
sudo apt update && sudo apt upgrade -y
sudo apt install curl tar wget clang pkg-config libpq-dev libssl-dev jq build-essential bsdmainutils git make ncdu gcc git jq chrony liblz4-tool libprotobuf-dev protobuf-compiler -y

#INSTALL RUST
echo "Installing Rust..."
echo "============================================================"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.bashrc
source $HOME/.cargo/env


#INSTALL POSTGRESQL
echo "Installing PostgreSQL..."
echo "============================================================"
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
apt-get -y install postgresql postgresql-client

#CONFIGURING POSTGRESQL
echo "Configuring PostgreSQL db..."
echo "============================================================"
su postgres <<EOF
createdb  $DB_NAME;
psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_USER_PASS';"
psql -c "grant all privileges on database $DB_NAME to $DB_USER;"
echo "Postgres User '$DB_USER' and database '$DB_NAME' created."
EOF

#INSTALL IPFS
echo "Installing IPFS..."
echo "============================================================"
wget https://dist.ipfs.tech/kubo/v0.15.0/kubo_v0.15.0_linux-amd64.tar.gz
tar -xvzf kubo_v0.15.0_linux-amd64.tar.gz
cd kubo
sh ./install.sh

echo "Installing Graph Node..."
echo "============================================================"
#INSTALL GRAPH NODE
cd $HOME
git clone https://github.com/graphprotocol/graph-node
carge build


#WRITE SYSTEMCTL FOR IPFS
tee $HOME/ipfs.service > /dev/null <<EOF
[Unit]
Description=IPFS daemon
After=network.target

[Service]
Environment=IPFS_PATH=~/.ipfs/datastore
ExecStart=/usr/local/bin/ipfs daemon
Restart=on-failure

[Install]
WantedBy=default.target
EOF

sudo mv $HOME/ipfs.service /etc/systemd/system/

# start service
sudo systemctl daemon-reload
sudo systemctl start ipfs
sudo systemctl enable ipfs

# start GRAPH NODE
cd $HOME/graph-node
cargo run -p graph-node --release -- \
  --postgres-url postgresql://$DB_USER:$DB_USER_PASS@localhost:5432/$DB_NAME \
  --ethereum-rpc canto:$RPC_URL \
  --ipfs 127.0.0.1:5001


break
;;

"Check Log")

journalctl -u ipfs -f -o cat

break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done