#!/bin/bash

set -e
set -o pipefail

APP_NAME="volisi"
BUILD_DIR="/home/ubuntu/build_jars"
PROD_DIR="/opt/testiqo/prod_jars"
BACKUP_DIR="/opt/testiqo/prod_jars_backup"
APP_LOG="/opt/testiqo/logs/${APP_NAME}.log"

mkdir -p "$BUILD_DIR" "$PROD_DIR" "$BACKUP_DIR" "/opt/testiqo/logs"

echo "Stopping existing process..."
pkill -f "${APP_NAME}.jar" 2>/dev/null || echo "No running process found."

# ---- BACKUP OLD JAR ----
if [ -f "$PROD_DIR/${APP_NAME}.jar" ]; then
  echo "Backing up current JAR as previous version..."
  cp -f "$PROD_DIR/${APP_NAME}.jar" "$BACKUP_DIR/${APP_NAME}_previous.jar"
  echo "Previous JAR stored at: $BACKUP_DIR/${APP_NAME}_previous.jar"
else
  echo "No existing JAR found in $PROD_DIR — skipping backup."
fi

# ---- MOVE NEW JAR ----
NEW_JAR=$(ls -t "$BUILD_DIR"/*.jar 2>/dev/null | head -n 1)
if [ -z "$NEW_JAR" ]; then
  echo "ERROR: No JAR file found in $BUILD_DIR"
  exit 1
fi

mv "$NEW_JAR" "$PROD_DIR/${APP_NAME}.jar"

# ---- START APPLICATION ----
nohup java -jar "$PROD_DIR/${APP_NAME}.jar" > "$APP_LOG" 2>&1 &

# ---- VERIFY ----
sleep 5
if pgrep -f "${APP_NAME}.jar" > /dev/null; then
  echo "Application started successfully!"
else
  echo "Application failed to start. Check logs at $APP_LOG"
fi
