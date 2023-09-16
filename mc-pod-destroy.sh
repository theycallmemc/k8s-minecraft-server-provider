#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 <servername>"
  exit 1
fi

servername="$1"

helm uninstall $servername -n minecraft