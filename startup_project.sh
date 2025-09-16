#!/bin/bash

# A script to set up a Raspberry Pi 5 for a CNN project
# with Jupyter Lab running as a service.

# --- Configuration ---
VENV_NAME="cats_vs_dogs"
PROJECT_DIR="/home/$(whoami)/projects"

# Ensure the script is run with sudo, but some commands as the user
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo: sudo ./setup_project.sh"
  exit
fi

# Step 1: Update and Upgrade System Packages
echo "🚀 Step 1: Updating and upgrading the system..."
apt-get update && apt-get full-upgrade -y

# Step 2: Install System Dependencies
echo "🛠️ Step 2: Installing system dependencies (Python, Git, etc.)..."
apt-get install -y python3-pip python3-venv git libatlas-base-dev

# Step 3: Create Project Directory and Virtual Environment (as the original user)
echo "📁 Step 3: Creating project directory and Python virtual environment..."
SUDO_USER=$(who -m | awk '{print $1;}')
sudo -u $SUDO_USER mkdir -p $PROJECT_DIR
sudo -u $SUDO_USER python3 -m venv $PROJECT_DIR/$VENV_NAME

# Step 4: Install Python Packages into the Virtual Environment
echo "🐍 Step 4: Installing Python packages (Jupyter, TFLite, Kaggle)..."
# The command is run inside a subshell to avoid changing the current shell's environment
sudo -u $SUDO_USER bash -c "source $PROJECT_DIR/$VENV_NAME/bin/activate && \
pip install --upgrade pip && \
pip install jupyterlab tflite-runtime kaggle kagglehub numpy Pillow matplotlib"

# Step 5: Configure and Enable Jupyter Lab as a systemd Service
echo "⚙️ Step 5: Setting up Jupyter Lab to run as a service..."

# Define the full path to the jupyter executable in the venv
JUPYTER_EXEC="$PROJECT_DIR/$VENV_NAME/bin/jupyter-lab"

# Create the systemd service file
cat <<EOF > /etc/systemd/system/jupyter.service
[Unit]
Description=Jupyter Lab Server for $SUDO_USER
After=network.target

[Service]
Type=simple
User=$SUDO_USER
ExecStart=$JUPYTER_EXEC --no-browser --ip=0.0.0.0 --notebook-dir=$PROJECT_DIR
WorkingDirectory=$PROJECT_DIR
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the new service
echo "▶️ Starting the Jupyter Lab service..."
systemctl daemon-reload
systemctl enable jupyter.service
systemctl start jupyter.service

echo -e "\n🎉 All done! Your Raspberry Pi is set up."
echo "Jupyter Lab is running as a service and will start on boot."
echo "You can check its status with: sudo systemctl status jupyter.service"

echo ip a
