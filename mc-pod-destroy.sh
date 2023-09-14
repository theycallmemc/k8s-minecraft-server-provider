#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 <servername>"
  exit 1
fi

servername="$1"

helm uninstall minecraft-$servername -n minecraft

while kubectl get pods -n minecraft | grep -q "minecraft-$servername"; do
  echo "Waiting for pod to terminate..."
  sleep 5
done

folder_path="/tmp/minecraft-data/$servername"

if [ -d "$folder_path" ]; then
  rm -rf "$folder_path"
fi
