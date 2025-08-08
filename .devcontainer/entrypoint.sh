#!/bin/bash


################################
### Docker configuration #######
################################
sudo chmod 666 /var/run/docker.sock

ROOT_DIR=$(pwd)
echo ${ROOT_DIR}
###########################
### Node dependencies #####
###########################
cd ${ROOT_DIR}/frontend
npm install

###########################
### Python dependencies ###
###########################
cd ${ROOT_DIR}/backend
poetry install -v --with dev --no-interaction --directory ${ROOT_DIR}/backend

cd ${ROOT_DIR}
#########################
### Git configuration ###
#########################
git config --global --add safe.directory ${ROOT_DIR}
pre-commit install
