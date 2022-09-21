#!/bin/bash

source $HOME/.cargo/env
cd $HOME/graph-node

cargo run -p graph-node --release -- --postgres-url postgresql://postgres:dbPassword@localhost:5432/canto_graph --ethereum-rpc canto:http://139.144.35.102:8545 --ipfs 127.0.0.1:5001
