#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 <servername>"
  exit 1
fi

servername="$1"

helm uninstall minecraft-$servername -n minecraft

folder_path="/tmp/minecraft-data/$servername"

if [ -d "$folder_path" ]; then
  rm -rf "$folder_path"

