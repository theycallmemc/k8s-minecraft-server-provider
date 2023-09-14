#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage: $0 <servername> <exposed_port>"
  exit 1
fi

servername="$1"
exposed_port="$2"

folder_path="/tmp/minecraft-data/$servername"
mkdir -p "$folder_path"
chmod 777 "$folder_path"

unique_release_name="minecraft-$servername" 

helm install $unique_release_name helm/minecraft --namespace minecraft --create-namespace \
  --set minecraft.motd="$unique_release_name" \
  --set minecraft.exposed_port=$exposed_port \
  --set volume.path="$folder_path" \
