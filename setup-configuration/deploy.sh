#!/bin/bash
# ============================================
# EC2 Initialization Script for Java App Deployment
# Author: Aaditya Jatale
# Purpose: Prepare EC2 for GitHub Action-based JAR deployment
# ============================================

set -e
set -o pipefail

echo "🚀 Starting EC2 setup for TestIQO deployment..."

# -------------------------------
# 1. Update and Install dependencies
# -------------------------------
apt-get update -y
apt-get install -y openjdk-17-jdk git unzip curl vim

# Verify Java installation
java -version

# -------------------------------
# 2. Create required directories
# -------------------------------
echo "📂 Creating directory structure..."
mkdir -p /opt/testiqo/{prod_jars,prod_jars_backup,deploy_logs,logs}
mkdir -p /home/ubuntu/build_jars

# -------------------------------
# 3. Create deploy.sh script
# -------------------------------
cat << 'EOF' > /opt/testiqo/deploy.sh
#!/bin/bash
# --------------------------------------------
# Author: Aaditya Jatale
# Purpose: Deploy single JAR on EC2 instance
# Triggered by GitHub Actions workflow
# --------------------------------------------

set -e
set -o pipefail

APP_NAME="myapp"  # Change this to your JAR name (without .jar)
BUILD_DIR="/home/ubuntu/build_jars"
PROD_DIR="/opt/testiqo/prod_jars"
BACKUP_DIR="/opt/testiqo/prod_jars_backup"
LOG_DIR="/opt/testiqo/deploy_logs"
APP_LOG="/opt/testiqo/logs/${APP_NAME}.log"
DEPLOY_LOG="${LOG_DIR}/deploy_$(date +'%Y-%m-%d_%H-%M-%S').log"

mkdir -p "$BUILD_DIR" "$PROD_DIR" "$BACKUP_DIR" "$LOG_DIR" "/opt/testiqo/logs"

echo "--------------------------------------------" | tee -a "$DEPLOY_LOG"
echo "🚀 Starting deployment for ${APP_NAME}" | tee -a "$DEPLOY_LOG"
echo "📅 Timestamp: $(date)" | tee -a "$DEPLOY_LOG"
echo "--------------------------------------------" | tee -a "$DEPLOY_LOG"

echo "🛑 Stopping existing process..." | tee -a "$DEPLOY_LOG"
pkill -f "${APP_NAME}.jar" 2>/dev/null || echo "No running process found." | tee -a "$DEPLOY_LOG"

if [ -f "$PROD_DIR/${APP_NAME}.jar" ]; then
  BACKUP_NAME="${APP_NAME}_$(date +'%y-%m-%d_%H-%M').jar"
  cp "$PROD_DIR/${APP_NAME}.jar" "$BACKUP_DIR/$BACKUP_NAME"
  echo "📦 Backed up old JAR to $BACKUP_DIR/$BACKUP_NAME" | tee -a "$DEPLOY_LOG"
else
  echo "ℹ️ No existing JAR found in $PROD_DIR" | tee -a "$DEPLOY_LOG"
fi

NEW_JAR=$(ls -t "$BUILD_DIR"/*.jar 2>/dev/null | head -n 1)
if [ -z "$NEW_JAR" ]; then
  echo "❌ ERROR: No JAR file found in $BUILD_DIR" | tee -a "$DEPLOY_LOG"
  exit 1
fi

echo "📁 Moving new JAR to production directory..." | tee -a "$DEPLOY_LOG"
mv "$NEW_JAR" "$PROD_DIR/${APP_NAME}.jar"

echo "▶️ Starting ${APP_NAME}..." | tee -a "$DEPLOY_LOG"
nohup java -jar "$PROD_DIR/${APP_NAME}.jar" > "$APP_LOG" 2>&1 &

echo "✅ Application started successfully!" | tee -a "$DEPLOY_LOG"
echo "--------------------------------------------" | tee -a "$DEPLOY_LOG"
echo "🎉 Deployment completed successfully for ${APP_NAME}" | tee -a "$DEPLOY_LOG"
echo "--------------------------------------------" | tee -a "$DEPLOY_LOG"
EOF

# -------------------------------
# 4. Set permissions and ownership
# -------------------------------
chmod +x /opt/testiqo/deploy.sh
chown -R ubuntu:ubuntu /opt/testiqo

# -------------------------------
# 5. (Optional) Start application on boot
# -------------------------------
cat << 'EOT' > /etc/systemd/system/myapp.service
[Unit]
Description=My Java App Service
After=network.target

[Service]
User=ubuntu
ExecStart=/usr/bin/java -jar /opt/testiqo/prod_jars/myapp.jar
SuccessExitStatus=143
Restart=always
RestartSec=10
StandardOutput=file:/opt/testiqo/logs/myapp.log
StandardError=file:/opt/testiqo/logs/myapp.log

[Install]
WantedBy=multi-user.target
EOT

# Enable service so it starts on reboot
systemctl daemon-reload
systemctl enable myapp.service

echo "✅ EC2 setup complete and ready for GitHub Actions deployment!"
