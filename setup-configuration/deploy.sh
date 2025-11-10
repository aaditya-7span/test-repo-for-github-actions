#!/bin/bash
# --------------------------------------------
# Author: Aaditya Jatale
# Purpose: Deploy single JAR on EC2 instance
# Triggered by GitHub Actions workflow
# --------------------------------------------

set -e
set -o pipefail

APP_NAME="volisi"  # Change this to your JAR name (without .jar)
BUILD_DIR="/home/ubuntu/build_jars"
PROD_DIR="/opt/testiqo/prod_jars"
BACKUP_DIR="/opt/testiqo/prod_jars_backup"
LOG_DIR="/opt/testiqo/deploy_logs"
APP_LOG="/opt/testiqo/logs/${APP_NAME}.log"
DEPLOY_LOG="${LOG_DIR}/deploy_$(date +'%Y-%m-%d_%H-%M-%S').log"

mkdir -p "$BUILD_DIR" "$PROD_DIR" "$BACKUP_DIR" "$LOG_DIR" "/opt/testiqo/logs"

echo "--------------------------------------------" | tee -a "$DEPLOY_LOG"
echo "Starting deployment for ${APP_NAME}" | tee -a "$DEPLOY_LOG"
echo "Timestamp: $(date)" | tee -a "$DEPLOY_LOG"
echo "--------------------------------------------" | tee -a "$DEPLOY_LOG"

echo "Stopping existing process..." | tee -a "$DEPLOY_LOG"
pkill -f "${APP_NAME}.jar" 2>/dev/null || echo "No running process found." | tee -a "$DEPLOY_LOG"

# ---- BACKUP OLD JAR ----
if [ -f "$PROD_DIR/${APP_NAME}.jar" ]; then
  echo "Backing up current JAR as previous version..." | tee -a "$DEPLOY_LOG"
  cp -f "$PROD_DIR/${APP_NAME}.jar" "$BACKUP_DIR/${APP_NAME}_previous.jar"
  echo "Previous JAR stored at: $BACKUP_DIR/${APP_NAME}_previous.jar" | tee -a "$DEPLOY_LOG"
else
  echo "No existing JAR found in $PROD_DIR — skipping backup." | tee -a "$DEPLOY_LOG"
fi

NEW_JAR=$(ls -t "$BUILD_DIR"/*.jar 2>/dev/null | head -n 1)
if [ -z "$NEW_JAR" ]; then
  echo "ERROR: No JAR file found in $BUILD_DIR" | tee -a "$DEPLOY_LOG"
  exit 1
fi

echo "Moving new JAR to production directory..." | tee -a "$DEPLOY_LOG"
mv "$NEW_JAR" "$PROD_DIR/${APP_NAME}.jar"

echo "Starting ${APP_NAME}..." | tee -a "$DEPLOY_LOG"
nohup java -jar "$PROD_DIR/${APP_NAME}.jar" > "$APP_LOG" 2>&1 &

echo "Application started successfully!" | tee -a "$DEPLOY_LOG"
echo "--------------------------------------------" | tee -a "$DEPLOY_LOG"
echo "Deployment completed successfully for ${APP_NAME}" | tee -a "$DEPLOY_LOG"
echo "--------------------------------------------" | tee -a "$DEPLOY_LOG"
