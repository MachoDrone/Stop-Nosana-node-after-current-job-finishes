#!/bin/bash

CONFIG_FILE="nosana_config_adv.conf"

# Default configuration values
CONTAINER_NAME="nosana-node"
LOG_FILE="nosana.log"
EMAIL_NOTIFICATION=false
EMAIL_ADDRESS=""
REMOVE_CONTAINER=false
RETRY_LIMIT=3
BACKUP_LOGS=false
BACKUP_DIR="backup_logs"
MAX_JOBS=1
MAX_TIME=0
API_KEY=""
API_PORT=5000
SERVER_URL="https://nos.justhold.org/api"
OPT_IN=false

# Load configuration if file exists
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
  echo "Configuration loaded from $CONFIG_FILE"
else
  echo "Configuration file $CONFIG_FILE not found"
fi

# Function to display help
display_help() {
  echo "Usage: $0 [options]"
  echo
  echo "   -c, --container-name   Docker container name (default: nosana-node)"
  echo "   -l, --log-file         Log file location (default: nosana.log)"
  echo "   -e, --email            Email address for notification"
  echo "   -r, --remove           Remove Docker container after stopping"
  echo "   -t, --time             Maximum time (in seconds) before shutting down"
  echo "   -j, --jobs             Number of jobs to be completed before shutting down"
  echo "   -b, --backup-logs      Backup logs before stopping the container"
  echo "   -a, --api-port         Port for the API server (default: 5000)"
  echo "   -u, --server-url       Server URL for live logging (default: https://nos.justhold.org/api)"
  echo "   -o, --opt-in           Opt-in for live log upload (true/false)"
  echo "   -h, --help             Display this help message"
  echo
}

# Prompt user for API configuration
read -p "Do you want to share logging info to view on nos.justhold.org (yes/y or no/n)? " share_logging

if [[ "$share_logging" == "yes" || "$share_logging" == "y" ]]; then
  OPT_IN=true
  API_KEY=$(openssl rand -hex 16)
  echo "API Key for accessing logs: $API_KEY"
  echo "API Endpoint: $SERVER_URL/logs.php?api_key=$API_KEY"
else
  OPT_IN=false
  API_KEY=""
  echo "Live logging to nos.justhold.org is disabled."
fi

# Parse command-line arguments
while [[ "$1" != "" ]]; do
  case $1 in
    -c | --container-name ) shift
                            CONTAINER_NAME=$1
                            ;;
    -l | --log-file )       shift
                            LOG_FILE=$1
                            ;;
    -e | --email )          shift
                            EMAIL_NOTIFICATION=true
                            EMAIL_ADDRESS=$1
                            ;;
    -r | --remove )         REMOVE_CONTAINER=true
                            ;;
    -t | --time )           shift
                            MAX_TIME=$1
                            ;;
    -j | --jobs )           shift
                            MAX_JOBS=$1
                            ;;
    -b | --backup-logs )    BACKUP_LOGS=true
                            ;;
    -a | --api-port )       shift
                            API_PORT=$1
                            ;;
    -u | --server-url )     shift
                            SERVER_URL=$1
                            ;;
    -o | --opt-in )         OPT_IN=true
                            ;;
    -h | --help )           display_help
                            exit 0
                            ;;
    * )                     display_help
                            exit 1
  esac
  shift
done

# Function to display animation
animate() {
  local delay=0.2
  local spin='/-\|'
  local i=0
  while :; do
    printf "\rwaiting for Nosana Job completion %c" "${spin:i++ % ${#spin}:1}"
    sleep "$delay"
  done
}

# Logging function
log_message() {
  local message="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
  echo "Logging message: $message"  # Debug output
  if $OPT_IN && [[ -n "$API_KEY" ]]; then
    echo "Curl command: curl -X POST -H \"Content-Type: text/plain\" --data \"$message\" \"$SERVER_URL/logs.php?api_key=$API_KEY\""  # Debug output
    response=$(curl -s -w "\n%{http_code}\n" -o /dev/null -X POST -H "Content-Type: text/plain" --data "$message" "$SERVER_URL/logs.php?api_key=$API_KEY")
    echo "Curl response: $response"  # Debug output
  fi
}

# Initial log messages
log_message "Script started with API key: $API_KEY"
log_message "Server URL for logging: $SERVER_URL"
log_message "Container name: $CONTAINER_NAME"
log_message "Log file location: $LOG_FILE"

echo -e "\n"
echo "------------------------------------------------"
echo "|                                              |"
echo "|  Nosana Node will STOP after job completion  |"
echo "|                                              |"
echo "------------------------------------------------"
echo -e "\n"

# If logging is enabled, show the API key and endpoint
if $OPT_IN; then
  echo "API Key for accessing logs: $API_KEY"
  echo "API Endpoint: $SERVER_URL/logs.php?api_key=$API_KEY"
fi

# Start the animation in the background
animate &
animation_pid=$!

# Error handling
error_exit() {
  log_message "Error: $1"
  echo "$1"
  kill "$animation_pid"
  exit 1
}

# Backup logs if enabled
backup_logs() {
  if $BACKUP_LOGS; then
    mkdir -p "$BACKUP_DIR"
    cp "$LOG_FILE" "$BACKUP_DIR/$(date '+%Y-%m-%d_%H-%M-%S')_$LOG_FILE"
    log_message "Logs backed up to $BACKUP_DIR"
  fi
}

# Confirm action
confirm_action() {
  read -p "Are you sure you want to remove the container $CONTAINER_NAME? (y/n): " choice
  case "$choice" in
    y|Y ) true;;
    n|N ) false;;
    * ) false;;
  esac
}

# Function to check disk space
check_disk_space() {
  df -h | grep "^/dev" | while read -r line; do
    log_message "Disk Space: $line"
    echo "Disk Space: $line"
  done
}

# Monitor Docker logs and job count
job_count=0
start_time=$(date +%s)

docker logs -n 5 -f "$CONTAINER_NAME" | while read -r line; do
  echo "$line" >> "$LOG_FILE"
  log_message "$line"  # Ensure every log line is being processed

  if echo "$line" | grep -q "Health check"; then
    job_count=$((job_count + 1))
    log_message "Job $job_count completed."

    # Check disk space after each job
    check_disk_space

    # Get job result and performance metrics
    job_result=$(echo "$line" | grep -oP 'result:\s*\K.*')
    performance_metrics=$(echo "$line" | grep -oP 'performance:\s*\K.*')
    log_message "Job Result: $job_result"
    log_message "Performance Metrics: $performance_metrics"

    if (( job_count >= MAX_JOBS )); then
      echo -e "\n"
      log_message "Maximum job count ($MAX_JOBS) reached. Stopping the container."

      # Retry logic for stopping the container
      retries=0
      while [[ $retries -lt $RETRY_LIMIT ]]; do
        if docker stop "$CONTAINER_NAME"; then
          log_message "Container stopped successfully."
          break
        else
          retries=$((retries + 1))
          log_message "Failed to stop the container. Retry $retries/$RETRY_LIMIT."
        fi
      done

      if [[ $retries -eq $RETRY_LIMIT ]]; then
        error_exit "Failed to stop the container after $RETRY_LIMIT attempts."
      fi

      echo "------------------------------------------------"
      echo "|                                              |"
      echo "|          Nosana Node -  STOPPED              |"
      echo "|                                              |"
      echo "------------------------------------------------"
      
      if $REMOVE_CONTAINER && confirm_action; then
        docker rm "$CONTAINER_NAME" || log_message "Failed to remove the container."
      fi
      
      if $EMAIL_NOTIFICATION && [[ -n "$EMAIL_ADDRESS" ]]; then
        echo "Nosana Node has stopped." | mail -s "Nosana Node Stopped" "$EMAIL_ADDRESS"
        log_message "Notification sent to $EMAIL_ADDRESS"
      fi
      
      backup_logs
      log_message "Nosana Node has stopped."
      kill "$animation_pid"
      exit 0
    fi
  fi

  # Check elapsed time
  elapsed_time=$(($(date +%s) - start_time))
  if (( MAX_TIME > 0 && elapsed_time >= MAX_TIME )); then
    log_message "Maximum time ($MAX_TIME seconds) reached. Stopping the container."

    # Retry logic for stopping the container
    retries=0
    while [[ $retries -lt $RETRY_LIMIT ]]; do
      if docker stop "$CONTAINER_NAME"; then
        log_message "Container stopped successfully."
        break
      else
        retries=$((retries + 1))
        log_message "Failed to stop the container. Retry $retries/$RETRY_LIMIT."
      fi
    done

    if [[ $retries -eq $RETRY_LIMIT ]]; then
      error_exit "Failed to stop the container after $RETRY_LIMIT attempts."
    fi

    echo "------------------------------------------------"
    echo "|                                              |"
    echo "|          Nosana Node -  STOPPED              |"
    echo "|                                              |"
    echo "------------------------------------------------"
    
    if $REMOVE_CONTAINER && confirm_action; then
      docker rm "$CONTAINER_NAME" || log_message "Failed to remove the container."
    fi
    
    if $EMAIL_NOTIFICATION && [[ -n "$EMAIL_ADDRESS" ]]; then
      echo "Nosana Node has stopped." | mail -s "Nosana Node Stopped" "$EMAIL_ADDRESS"
      log_message "Notification sent to $EMAIL_ADDRESS"
    fi
    
    backup_logs
    log_message "Nosana Node has stopped."
    kill "$animation_pid"
    exit 0
  fi
done
