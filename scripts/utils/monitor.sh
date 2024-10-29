#!/bin/bash

echo "Stato container:"
docker-compose ps

echo -e "\nUtilizzo risorse:"
docker stats --no-stream $(docker-compose ps -q)

echo -e "\nUltimi log:"
docker-compose logs --tail=20
