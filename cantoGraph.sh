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

#handle blanks with defaults
if [ "$RPC_URL" = "" ]
then
    echo export RPC_URL="http://139.144.35.102:8545" >> $HOME/.bash_profile
else
    echo export RPC_URL=${RPC_URL} >> $HOME/.bash_profile
fi
if [ "$DB_NAME" = "" ]
then
    echo export DB_NAME="canto_graph" >> $HOME/.bash_profile
else
    echo export DB_NAME=${DB_NAME} >> $HOME/.bash_profile
fi
if [ "$DB_USER" = "" ]
then
    echo export DB_USER="dbadmin" >> $HOME/.bash_profile
else
    echo export DB_USER=${DB_USER} >> $HOME/.bash_profile
fi
if [ "$DB_USER_PASS" = "" ]
then
    echo export DB_USER_PASS="dbPassword" >> $HOME/.bash_profile
else
    echo export DB_USER_PASS=${DB_USER_PASS} >> $HOME/.bash_profile
fi

source ~/.bash_profile

#UPDATE APT -hold for testing
apt update && apt upgrade -y
apt install curl tar wget clang pkg-config libpq-dev libssl-dev jq build-essential bsdmainutils git make ncdu gcc git jq chrony liblz4-tool libprotobuf-dev protobuf-compiler -y

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
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
apt-get -y install postgresql postgresql-client

#CONFIGURING POSTGRESQL
echo "Configuring PostgreSQL db..."
echo "============================================================"
set -e

mkdir /home/db && cd /home/db
chmod og+rX /home/db



su postgres <<EOF
if [ "$( psql -XtAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" )" = '0' ]
then
    createdb  $DB_NAME;
    psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_USER_PASS';"
    psql -c "grant all privileges on database $DB_NAME to $DB_USER;"
    echo "Postgres User '$DB_USER' and database '$DB_NAME' created."
fi

EOF

#INSTALL IPFS
echo "Installing IPFS..."
echo "============================================================"
cd $HOME
wget https://dist.ipfs.tech/kubo/v0.15.0/kubo_v0.15.0_linux-amd64.tar.gz
tar -xvzf kubo_v0.15.0_linux-amd64.tar.gz
cd kubo
sh ./install.sh

cd $HOME
sysctl -w net.core.rmem_max=2500000
ipfs init

echo "Installing Graph Node..."
echo "============================================================"
#INSTALL GRAPH NODE
cd $HOME
git clone https://github.com/graphprotocol/graph-node
carge build


#WRITE AND LAUNCH SYSTEMCTL FOR IPFS
tee $HOME/ipfs.service > /dev/null <<EOF
[Unit]
Description=IPFS daemon
After=network.target

[Service]
Environment=IPFS_PATH=$HOME/.ipfs
ExecStart=/usr/local/bin/ipfs daemon
Restart=on-failure

[Install]
WantedBy=default.target
EOF

mv $HOME/ipfs.service /etc/systemd/system/

# start service
systemctl daemon-reload
systemctl start ipfs
systemctl enable ipfs

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