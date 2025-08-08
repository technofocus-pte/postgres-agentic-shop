#!/bin/bash

if [ -f ./arize-phoenix/.env ]; then
  echo "[INFO] Starting Arize..."
  docker compose -f .devcontainer/docker-compose.yml --profile tracing --env-file ./arize-phoenix/.env up -d arize-phoenix
else
  echo "[WARN] Skipping Arize: .env missing"
fi
