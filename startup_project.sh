#!/bin/bash

# A script to set up a Debian server for a CNN project
# with Jupyter Lab running as a service. (v6 - Fixes tmpfs space issue)

# --- Configuration ---
VENV_NAME="cats_vs_dogs"
PROJECT_DIR="/home/$SUDO_USER/projects"
# NEW: Define a temporary directory on the main disk
PIP_TMP_DIR="/home/$SUDO_USER/tmp_pip"

# Ensure the script is run with sudo from a regular user account
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ]; then
  echo "Error: Please run this script from a regular user account using sudo."
  echo "Example: sudo ./setup_project.sh"
  exit 1
fi

# Step 1: Update and Upgrade System Packages
echo "🚀 Step 1: Updating and upgrading the system..."
apt-get update && apt-get full-upgrade -y

# Step 2: Install System Dependencies
echo "🛠️ Step 2: Installing system dependencies (Python, Git, etc.)..."
apt-get install -y python3-pip python3-venv python3.13-venv git libopenblas-dev

# Step 3: Create Project Directory and Virtual Environment (as the original user)
echo "📁 Step 3: Creating project directory and Python virtual environment for user '$SUDO_USER'..."
sudo -u $SUDO_USER mkdir -p $PROJECT_DIR
# NEW: Create the temporary directory for pip
sudo -u $SUDO_USER mkdir -p $PIP_TMP_DIR
sudo -u $SUDO_USER python3 -m venv $PROJECT_DIR/$VENV_NAME

# Step 4: Install Python Packages into the Virtual Environment
echo "🐍 Step 4: Installing Python packages (Jupyter, TensorFlow, Kaggle)..."
# MODIFIED: Use the new temp dir for the pip install command
sudo -u $SUDO_USER bash -c "source $PROJECT_DIR/$VENV_NAME/bin/activate && \
export TMPDIR=$PIP_TMP_DIR && \
pip install --upgrade pip && \
pip install jupyterlab tensorflow kaggle kagglehub numpy Pillow matplotlib"

# Step 5: Configure and Enable Jupyter Lab as a systemd Service
echo "⚙️ Step 5: Setting up Jupyter Lab to run as a service..."

JUPYTER_EXEC="$PROJECT_DIR/$VENV_NAME/bin/jupyter-lab"

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

sleep 3

echo -e "\n🎉 All done! Your server is set up."
echo "You can check the service status with: sudo systemctl status jupyter.service"

# --- Display Access Information ---
echo -e "\n\n🌐 Finding your Jupyter Lab access URL..."
echo "Giving the server 5 seconds to start up..."
sleep 5

IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo -e "\nYour server's main IP address is: \033[1;32m$IP_ADDRESS\033[0m"
echo "Searching for the Jupyter Lab URL with access token..."

sudo -u $SUDO_USER bash -c "source $PROJECT_DIR/$VENV_NAME/bin/activate && jupyter server list"

echo -e "\n➡️ To connect, open a web browser on another computer and go to the URL shown above."
echo "   If the URL shows 'localhost' or '127.0.0.1', replace it with your IP address."
echo -e "   Example: \033[1;33mhttp://$IP_ADDRESS:8888/lab?token=...\033[0m"

# Final cleanup of the temporary directory
sudo -u $SUDO_USER rm -rf $PIP_TMP_DIR
echo "Cleaned up temporary directory."
