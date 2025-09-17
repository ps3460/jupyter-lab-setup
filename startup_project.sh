#!/bin/bash

# A script to set up a Debian server with a central Jupyter Lab
# running from its own dedicated venv.

# --- Configuration ---
PROJECTS_DIR="/home/$SUDO_USER/projects"
JUPYTER_VENV_PATH="/home/$SUDO_USER/jupyter_env"

# Ensure the script is run with sudo from a regular user account
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ]; then
  echo "Error: Please run this script from a regular user account using sudo."
  echo "Example: sudo ./setup.sh"
  exit 1
fi

# Step 1: Install System Dependencies
echo "🚀 Step 1: Installing system dependencies..."
apt-get update && apt-get full-upgrade -y
apt-get install -y python3-pip python3-full git libopenblas-dev

# Step 2: Create and Install Jupyter Lab in its own Venv
echo "💻 Step 2: Creating a dedicated environment for Jupyter Lab..."
sudo -u $SUDO_USER python3 -m venv "$JUPYTER_VENV_PATH"

echo "Installing Jupyter Lab into its environment..."
sudo -u $SUDO_USER bash -c "source \"$JUPYTER_VENV_PATH/bin/activate\" && \
pip install --upgrade pip && \
pip install jupyterlab"

# Step 3: Get Project Details from User
echo -e "\n📝 Step 3: Now, let's create a separate environment for your project."
echo "   (e.g., 'venv-01', 'data_analysis', 'cnn-ai' etc.)"
VENV_NAME=""
while [ -z "$VENV_NAME" ]; do
    read -p "Enter a name for the project's virtual environment: " VENV_NAME
done
PROJECT_VENV_PATH="$PROJECTS_DIR/$VENV_NAME"
echo "Project environment will be created at: $PROJECT_VENV_PATH"

# Step 4: Create Project Venv and Register it as a Kernel
echo "🐍 Step 4: Creating project venv and installing packages..."
sudo -u $SUDO_USER mkdir -p "$PROJECTS_DIR"
sudo -u $SUDO_USER python3 -m venv "$PROJECT_VENV_PATH"

echo "Installing project packages and registering the kernel..."
sudo -u $SUDO_USER bash -c "source \"$PROJECT_VENV_PATH/bin/activate\" && \
pip install --upgrade pip && \
pip install ipykernel tensorflow opencv-python matplotlib kaggle kagglehub numpy Pillow && \
python -m ipykernel install --user --name=\"$VENV_NAME\" --display-name=\"Python ($VENV_NAME)\""

# Step 5: Set up the Jupyter Lab Service
echo "⚙️ Step 5: Setting up the Jupyter Lab service..."
JUPYTER_EXEC="$JUPYTER_VENV_PATH/bin/jupyter-lab"

cat <<EOF > /etc/systemd/system/jupyter.service
[Unit]
Description=Jupyter Lab Server (from $JUPYTER_VENV_PATH)
After=network.target

[Service]
Type=simple
User=$SUDO_USER
ExecStart=$JUPYTER_EXEC --no-browser --ip=0.0.0.0 --notebook-dir=$PROJECTS_DIR
WorkingDirectory=$PROJECTS_DIR
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the new service
echo "▶️ Starting the Jupyter Lab service..."
systemctl daemon-reload
systemctl enable jupyter.service
systemctl restart jupyter.service

echo -e "\n🎉 All done! Your Jupyter Lab server is ready."
echo "It is running from its own environment, and your project kernel '$VENV_NAME' is available."
