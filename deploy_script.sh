#!/usr/bin/env bash
# The first line will auto run script.


#  Error handling
set -Eeuo pipefail

# STEP 1: VALIDATION.

echo "Validating Packages/Services..."

# CURL 

command -v curl >/dev/null 2>&1 && echo "curl is installed" || echo "curl is NOT installed"


# DOCKER 

command -v docker >/dev/null 2>&1 && echo "Docker is installed" || echo "Docker is NOT installed"


# DOCKER COMPOSE

command -v docker-compose >/dev/null 2>&1 && echo "Docker Compose is installed" || echo "Docker Compose is NOT installed"


# PORT AVILABILITY.

# Check backend port.
ss -tuln | grep -q ":5000" && echo "Port is available" || { echo "Port is not available"; exit 1; }

# Check MongoDB port

ss -tuln | grep -q ":27017" && echo "Port is available" || { echo "Port is not available"; exit 1; }

# Check studentportfolio port

ss -tuln | grep -q ":3000" && echo "Port is available" || { echo "Port is not available"; exit 1; }

# Check nginx port
ss -tuln | grep -q ":80" && echo "Port is available" || { echo "Port is not available"; exit 1; }


# STEP 2 - CHANGE DIRECTORY

cd "/mnt/c/Users/www_k/Documents/1-RRC BIT/Fall Term 4/DevOps/DevopsA06/Williams_Akeem_Module_6Part1" || { echo "Cannot find path"; exit 1; }

# -f will check if file exits?

# [] are for tests 
[ -f docker-compose.yaml ] && echo "docker-compose.yaml found!" || { echo "docker-compose.yaml not found"; exit 1; }


# STEP 3 - Build & DEPLOY WITH COMPOSE

# build and start containers
echo "Building and starting containers..."
docker compose up -d --build && echo "Build & deploy succeeded" || echo "Build & deploy failed"

# Show all local Docker images.
echo "Listing images..."
docker images && echo "Build & display images succeeded" || echo "display images failed"

# Show all currently running containers.
echo "Listing running containers..."
docker ps && echo "list containers succeeded" || echo "list containers failed"

# HELATH CHECKS

curl -s http://localhost:5000 >/dev/null 2>&1 && echo "Service healthy" || echo "Service unreachable"

curl -s http://localhost:27017 >/dev/null 2>&1 && echo "Service healthy" || echo "Service unreachable"

curl -s http://localhost:3000 >/dev/null 2>&1 && echo "Service healthy" || echo "Service unreachable"

# MongoDB (non-HTTP service)
# scan only and verbose
nc -zv localhost 27017 >/dev/null 2>&1 && echo "27017 healthy" || echo "27017 unreachable"


# COLLECT NGINX ID

# awk '{print $1}' extracts the first column (container ID).
# [ -n "$NGINX_ID" ] checks if the variable is non‑empty. 

NGINX_ID=$(docker ps | grep nginx | awk '{print $1}')
[ -n "$NGINX_ID" ] && echo "Found nginx container: $NGINX_ID" || echo "No nginx container found"


# 200 STATUS CODE

 # Everything with () will return status code  then compare if equal.
 # [] is a test btw.

[ "$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000)" -eq 200 ] && echo "5000 OK" || echo "5000 FAIL"


[ "$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)" -eq 200 ] && echo "3000 OK" || echo "3000 FAIL"

[ "$(curl -s -o /dev/null -w "%{http_code}" http://localhost:80)" -eq 200 ] && echo "80 OK" || echo "80 FAIL"

nc -z localhost 27017 && echo "27017 OK" || echo "27017 FAIL"


# JQ INSTALATIONS

#jq is command line json processor. We can minipulate json in terminal.

#Install JQ 
# -y to all prompts.
sudo apt-get update && sudo apt-get install -y jq && echo "jq installed" || { echo "jq install failed"; exit 1; }

# this will redirect the log files or create if doesnt exist.
docker inspect nginx:alpine > nginx-logs.txt && echo "Log saved to nginx-logs.txt" || echo "Failed to save log"


# Extaction
# .[0] this is the first object in the entrie overall array.
# .Repotags would be the keys. so its loging that info.


echo "RepoTags:"
jq '.[0].RepoTags' nginx-logs.txt

echo "Created:"
jq '.[0].Created' nginx-logs.txt

echo "Os:"
jq '.[0].Os' nginx-logs.txt

echo "Config:"
jq '.[0].Config' nginx-logs.txt

echo "ExposedPorts:"
jq '.[0].Config.ExposedPorts' nginx-logs.txt