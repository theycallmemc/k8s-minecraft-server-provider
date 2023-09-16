#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage: $0 <servername> <exposed_port>"
  exit 1
fi

servername="$1"
exposed_port="$2"

helm install $servername helm/minecraft --namespace minecraft --create-namespace \
  --set minecraft.motd="$servername" \
  --set minecraft.exposed_port=$exposed_port
