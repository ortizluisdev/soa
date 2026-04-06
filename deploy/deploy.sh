#!/bin/bash

echo "🚀 Iniciando deploy..."

cd ~/soa || exit

docker compose down
docker compose up -d --build

echo "DEPLOY_OK"
