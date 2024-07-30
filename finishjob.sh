#!/bin/bash
rm -r finishjob-installer.sh
echo -e "\n"
echo "------------------------------------------------"
echo "|                                              |"
echo "|  Nosana Node will STOP after job completion  |"
echo "|                                              |"
echo "------------------------------------------------"
echo -e "\n"

# Set the name of your Docker container
CONTAINER_NAME="nosana-node"

# Function to display animation
animate() {
  local delay=0.2
  local spin='/-\|'
  local i=0
  while :; do
    printf "\rWaiting for Nosana Job completion %c" "${spin:i++ % ${#spin}:1}"
    sleep "$delay"
  done
}

# Start the animation in the background
animate &

# Capture the PID of the animation
animation_pid=$!

# Monitor Docker logs
docker logs -n 5 -f "$CONTAINER_NAME" | while read -r line; do
  if echo "$line" | grep -q "Health check"; then
    echo -e "\n"
#    docker logs -t -n 50 nosana-node
    docker stop nosana-node
echo "------------------------------------------------"
echo "------------------------------------------------"
echo "------------------------------------------------"
echo "------------------------------------------------"
echo "------------------------------------------------"
echo "------------------------------------------------"
echo "|                                              |"
echo "|          Nosana Node -  STOPPED              |"
echo "|                                              |"
echo "------------------------------------------------"
echo "------------------------------------------------"
echo "------------------------------------------------"
echo "------------------------------------------------"
echo "------------------------------------------------"
echo "------------------------------------------------"
echo -e "\n"
    kill "$animation_pid"
    exit 0
  fi
done
