#!/bin/bash
# Shebang: tells the system to run this script using the Bash shell.

# Safety flags:
# -e : Exit immediately if any command fails.
# -u : Treat unset variables as errors and exit.
# -o pipefail : If any command in a pipeline fails, the whole pipeline fails.
set -euo pipefail

# docker compose up -d --build

# Print a header message so the user knows deployment has started.
echo "=== Pixel River Financial Bank Deployment ==="

# -----------------------------
# 1. Validate prerequisites
# -----------------------------

# Check if Docker is installed.
# 'command -v docker' checks if the 'docker' command exists in PATH.
# '&> /dev/null' hides both standard output and error messages.
if ! command -v docker &> /dev/null; then
  echo "Docker is not installed. Please install Docker first."
  exit 1
fi

# Check if Docker Compose is installed.
# First try the new plugin 'docker compose'.
# If that fails, check for the older standalone 'docker-compose'.
# If neither is found, exit with an error.
if docker compose version &> /dev/null; then
  echo "Docker Compose plugin found."
elif command -v docker-compose &> /dev/null; then
  echo "Standalone docker-compose found."
else
  echo "Docker Compose not installed. Please install it."
  exit 1
fi

# Check if required ports are available.
# Ports: 27017 (MongoDB), 5000 (Backend), 3000 (Frontend), 80 (nginx).
# 'ss -ltn' lists listening TCP ports.
# 'grep -q ":$port"' searches for the port number.
PORTS=(27017 5000 3000 80)
for port in "${PORTS[@]}"; do
  if ss -ltn | grep -q ":$port"; then
    echo "WARNING: Port $port is already in use."
    exit 1
  else
    echo "Port $port is available."
  fi
done

# -----------------------------
# 2. Validate docker-compose.yml
# -----------------------------

# PROJECT_DIR stores the directory where this script lives.
PROJECT_DIR="$(dirname "$0")"
# Change into that directory so relative paths work correctly.
cd "$PROJECT_DIR"

# Check if docker-compose.yml exists in the same folder as the script.
if [ ! -f "docker-compose.yaml" ]; then
  echo "docker-compose.yaml not found in $PROJECT_DIR"
  exit 1
fi
echo "Found docker-compose.yaml in $PROJECT_DIR"

# -----------------------------
# 3. Build & deploy
# -----------------------------

echo "Building and starting containers..."
# Build images defined in docker-compose.yml.
docker compose build
# Start containers in detached mode (runs in background).
docker compose up -d

# Show all local Docker images.
echo "Listing images..."
docker images

# Show all currently running containers.
echo "Listing running containers..."
docker ps

# -----------------------------
# 4. Health checks
# -----------------------------

echo "Checking services..."
# Loop through frontend (3000) and backend (5000) URLs.
# 'curl -s --head' requests only HTTP headers silently.
# 'grep "200 OK"' checks if the service responded successfully.
for url in http://localhost:3000 http://localhost:5000 http://localhost; do
  if curl -s --head $url | grep "200 OK" > /dev/null; then
    echo "Service at $url is healthy."
  else
    echo "Warning: $url not responding."
  fi
done

# Check MongoDB port separately (since it's not HTTP)
if ss -ltn | grep -q ":27017"; then
  echo "MongoDB port 27017 is open."
else
  echo "Warning: MongoDB port 27017 not open."
fi

echo "Validating nginx page render..."
# Fetch the first 5 lines of the nginx homepage to confirm HTML is served
if curl -s http://localhost | head -n5 | grep -q "<html"; then
  echo "nginx is serving a valid HTML page."
else
  echo "Warning: nginx did not return expected HTML content."
fi


# -----------------------------
# 5. Capture nginx container ID
# -----------------------------

# Find the container ID of the nginx:alpine container.
# '--filter "ancestor=nginx:alpine"' finds containers created from that image.
# '--format "{{.ID}}"' outputs only the container ID.
# 'head -n1' takes the first ID if multiple exist.
NGINX_ID=$(docker ps --filter "ancestor=nginx:alpine" --format "{{.ID}}" | head -n1)
echo "nginx container ID: $NGINX_ID"

# -----------------------------
# 6. Ensure jq installed
# -----------------------------

# 'jq' is a JSON processor used to extract fields from Docker image inspection.
# If not installed, update apt package list and install jq automatically.
if ! command -v jq &> /dev/null; then
  echo "Installing jq..."
  sudo apt-get update && sudo apt-get install -y jq
fi

# -----------------------------
# 7. Inspect nginx image
# -----------------------------

echo "Inspecting nginx:alpine image..."
# 'docker image inspect' outputs detailed JSON metadata about the image.
# Redirect output into nginx-logs.json for later parsing.
docker image inspect nginx:alpine > nginx-logs.json

echo "Extracting keys..."
# Use jq to pull specific fields from the JSON and save them into nginx-logs.txt.
{
  echo "RepoTags:"; jq -r '.[0].RepoTags' nginx-logs.json
  echo "Created:"; jq -r '.[0].Created' nginx-logs.json
  echo "Os:"; jq -r '.[0].Os' nginx-logs.json
  echo "Config:"; jq -r '.[0].Config' nginx-logs.json
  echo "ExposedPorts:"; jq -r '.[0].Config.ExposedPorts' nginx-logs.json
} > nginx-logs.txt

# -----------------------------
# 8. Finish
# -----------------------------

# Print completion message and tell user where to find extracted values.
echo "Deployment complete!"
echo "Check nginx-logs.txt for extracted values."
