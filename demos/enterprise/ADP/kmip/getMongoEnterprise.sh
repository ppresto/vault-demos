#!/bin/bash

DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
VERSION="4.2.3"
MONGO_PLATFORM="mongodb-macos-x86_64-enterprise"

# Download
if [[ ! -f ${MONGO_PLATFORM}-${VERSION}.tgz ]]; then
  echo "curl https://downloads.mongodb.com/osx/${MONGO_PLATFORM}-${VERSION}.tgz \
    -o ${DIRECTORY}/${MONGO_PLATFORM}-${VERSION}.tgz"

  curl https://downloads.mongodb.com/osx/${MONGO_PLATFORM}-${VERSION}.tgz \
    -o ${DIRECTORY}/${MONGO_PLATFORM}-${VERSION}.tgz

  # Extract
  tar -zxvf ${DIRECTORY}/${MONGO_PLATFORM}-${VERSION}.tgz
fi

export PATH=$PATH:${DIRECTORY}/${MONGO_PLATFORM}-${VERSION}/bin

# Create Data Dir
#mkdir -p /usr/local/var/mongodb /usr/local/var/log/mongodb
#mkdir -p ${DIR}/mongodb

# Create Log Dir
#sudo mkdir -p /usr/local/var/log/mongodb

# Set Permissions
#sudo chown my_mongodb_user /usr/local/var/mongodb
#sudo chown my_mongodb_user /usr/local/var/log/mongodb

# Run MongoDB
#mongod --dbpath /usr/local/var/mongodb --logpath /usr/local/var/log/mongodb/mongo.log --bind_ip_all --fork
#mongod --dbpath ${DIRECTORY}/mongodb --logpath ${DIRECTORY}/mongo.log --bind_ip_all --fork

# Verify MongoDB Process
#ps aux | grep -v grep | grep mongod

