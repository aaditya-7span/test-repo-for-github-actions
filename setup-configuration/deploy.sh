#!/bin/bash

set -e
set -o pipefail

APP_NAME="volisi"
BUILD_DIR="/home/ubuntu/build_jars"
PROD_DIR="/opt/volisi/prod_jars"
BACKUP_DIR="/opt/volisi/prod_jars_backup"
APP_LOG="/opt/volisi/logs/${APP_NAME}.log"

mkdir -p "$BUILD_DIR" "$PROD_DIR" "$BACKUP_DIR" "/opt/testiqo/logs"

echo "Starting deployment for ${APP_NAME}"

echo "Stopping existing process (if any)..."
pkill -f "${APP_NAME}.jar" 2>/dev/null || echo "No running process found."

if [ -f "$PROD_DIR/${APP_NAME}.jar" ]; then
  echo "Backing up current JAR with timestamp..."

  # Remove any existing backup before creating new one
  echo "Cleaning up old backup (if any)..."
  rm -f "$BACKUP_DIR"/*.jar 2>/dev/null || true

  # Create new timestamped backup file
  TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
  BACKUP_NAME="${APP_NAME}_${TIMESTAMP}.jar"
  cp -f "$PROD_DIR/${APP_NAME}.jar" "$BACKUP_DIR/$BACKUP_NAME"
  echo "Backup created: $BACKUP_DIR/$BACKUP_NAME"
else
  echo "No existing JAR found in $PROD_DIR — skipping backup."
fi

# ---- MOVE NEW JAR ----
NEW_JAR=$(ls -t "$BUILD_DIR"/*.jar 2>/dev/null | head -n 1)
if [ -z "$NEW_JAR" ]; then
  echo "ERROR: No JAR file found in $BUILD_DIR"
  exit 1
fi

echo "Moving new JAR to production directory..."
mv -f "$NEW_JAR" "$PROD_DIR/${APP_NAME}.jar"
echo "New JAR moved successfully."

# ---- START APPLICATION ----
echo "Starting ${APP_NAME}..."
nohup java -jar "$PROD_DIR/${APP_NAME}.jar" > "$APP_LOG" 2>&1 &

# ---- VERIFY ----
sleep 5
if pgrep -f "${APP_NAME}.jar" > /dev/null; then
  echo "Application started successfully!"
else
  echo "Application failed to start. Check logs at $APP_LOG"
fi

echo "Deployment completed successfully for ${APP_NAME}"
