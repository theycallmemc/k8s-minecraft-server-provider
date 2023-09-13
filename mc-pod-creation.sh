#!/bin/bash

if [ $# -ne 3 ]; then
  echo "Usage: $0 <servername> <internal_port> <exposed_port>"
  exit 1
fi

servername="$1"
internal_port="$2"
exposed_port="$3"

unique_folder_name="minecraft-data-$servername"
folder_path="/tmp/minecraft-data/$unique_folder_name"
mkdir -p "$folder_path"
chmod 777 "$folder_path"

unique_release_name="minecraft-$servername" 

helm install $unique_release_name helm/minecraft --namespace minecraft --create-namespace \
  --set minecraft.motd="$unique_release_name" \
  --set minecraft.internal_port=$internal_port \
  --set minecraft.exposed_port=$exposed_port \
  --set volume.path="$folder_path" \
