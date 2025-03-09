#!/bin/bash
# Define the date variable
DATE=$(date +'%Y-%m-%d')

# MySQL container name (please change this to the actual container name or ID)
MYSQL_CONTAINER="mysql_container"

# List all database names to back up (modify as needed)
DATABASES=(
  "db1"
  "db2"
  "db3"
  "db4"
)

# Define the log file path
LOGFILE="/var/log/backup_dbs.log"
# If the log file directory is not writable, use /tmp instead
if [ ! -w "$(dirname "$LOGFILE")" ]; then
    LOGFILE="/tmp/backup_dbs.log"
fi

# Loop through each database to perform backup
for DB in "${DATABASES[@]}"; do
    echo "Backing up database: $DB"
    
    # Define the backup file path and name (temporarily save in /tmp on the host)
    BACKUP_FILE="/tmp/${DB}_backup_${DATE}.sql.gz"
    
    echo "Please enter the MySQL root password when prompted to back up database $DB"
    # Execute mysqldump inside the MySQL container via docker exec (using root user and prompting for password)
    docker exec -i "$MYSQL_CONTAINER" \
        mysqldump -u root -p "$DB" | gzip > "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - Error: mysqldump failed for database $DB" >> "$LOGFILE"
        continue  # If export fails, skip this database
    fi
    
    # Define the remote storage path (assumes rclone remote is named dropbox, and the target directory is backup)
    REMOTE="dropbox:backup/${DB}_backup_${DATE}.sql.gz"
    
    # Use rclone to copy the backup file to the cloud storage
    rclone copy "$BACKUP_FILE" "$REMOTE" --verbose
    if [ $? -ne 0 ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - Error: rclone upload failed for database $DB" >> "$LOGFILE"
        continue  # If upload fails, skip the deletion step and proceed with the next database
    fi
    
    # Optionally, delete the local backup file after uploading
    rm -f "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - Warning: Failed to delete local backup file for database $DB" >> "$LOGFILE"
    fi
    
    echo "Database $DB backup completed."
done

echo "All database backups completed."
