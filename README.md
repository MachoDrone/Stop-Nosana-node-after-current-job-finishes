
# README for Nosana Node Stopper Advanced

This README provides detailed instructions on setting up and running the Nosana Node Stopper Advanced script.

---

## Nosana Node Stopper Advanced

The `nosana_node_stopper_adv.sh` script automates the process of running a Nosana Node Docker container, logging its activity, and optionally uploading these logs to a remote server for live viewing.

### Features

- Automatic Docker container management
- Configurable logging to a file and remote server
- Email notifications upon job completion
- Backup of log files
- Disk space monitoring

### Prerequisites

- Docker installed on your system
- A remote server with PHP and MySQL support
- cURL installed on your system
- OpenSSL installed for generating API keys

### Configuration

Create a configuration file named `nosana_config_adv.conf` in the same directory as the script. Here is an example configuration file:

```conf
# Configuration for Nosana Node Stopper Advanced Script

# Name of the Docker container
CONTAINER_NAME="nosana-node"

# Log file location
LOG_FILE="nosana.log"

# Enable email notification (true/false)
EMAIL_NOTIFICATION=false

# Email address for notification
EMAIL_ADDRESS=""

# Remove Docker container after stopping (true/false)
REMOVE_CONTAINER=false

# Retry limit for stopping the container
RETRY_LIMIT=3

# Backup logs before stopping the container (true/false)
BACKUP_LOGS=false

# Directory to save backup logs
BACKUP_DIR="backup_logs"

# Maximum jobs to complete before shutting down
MAX_JOBS=1

# Maximum time (in seconds) to wait before shutting down
MAX_TIME=0

# API port for the Flask server
API_PORT=5000

# Server URL for live logging
SERVER_URL="https://nos.justhold.org/api"
```

### Script Usage

```bash
./nosana_node_stopper_adv.sh
```

### Command-Line Arguments

The script supports several command-line arguments to override default configuration settings:

- `-c, --container-name`: Docker container name
- `-l, --log-file`: Log file location
- `-e, --email`: Email address for notification
- `-r, --remove`: Remove Docker container after stopping
- `-t, --time`: Maximum time (in seconds) before shutting down
- `-j, --jobs`: Number of jobs to be completed before shutting down
- `-b, --backup-logs`: Backup logs before stopping the container
- `-a, --api-port`: Port for the API server
- `-u, --server-url`: Server URL for live logging
- `-o, --opt-in`: Opt-in for live log upload (true/false)
- `-h, --help`: Display help message

### Example

```bash
./nosana_node_stopper_adv.sh -c nosana-node -l nosana.log -e user@example.com -r -t 3600 -j 10 -b -a 5000 -u https://nos.justhold.org/api -o
```

## Setting Up the Remote Server for Live Logging

### PHP API Script (`api/logs.php`)

Here is an example PHP script to handle log data and save it to a MySQL database:

```php
<?php
// api/logs.php

require 'config.php';

header('Content-Type: application/json');

$api_key = $_GET['api_key'] ?? '';
$log_data = file_get_contents('php://input');

// Debug output
error_log("API Key: $api_key");
error_log("Log Data: $log_data");

if (empty($api_key) || empty($log_data)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid request']);
    exit;
}

// Save log data to the database
try {
    $pdo = new PDO($dsn, $username, $password, $options);
    $stmt = $pdo->prepare("INSERT INTO logs (api_key, log_data, created_at) VALUES (?, ?, NOW())");
    $stmt->execute([$api_key, $log_data]);

    // Debugging output
    error_log("Log successfully saved to the database.");

    echo json_encode(['success' => 'Log saved successfully']);
} catch (PDOException $e) {
    http_response_code(500);
    error_log('Database error: ' . $e->getMessage());
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
}
?>
```

### MySQL Database

Create a MySQL database and table to store the logs:

```sql
CREATE DATABASE nosana_logs;
USE nosana_logs;

CREATE TABLE logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    api_key VARCHAR(32) NOT NULL,
    log_data TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

