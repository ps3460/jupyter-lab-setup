#!/bin/bash

# A script to set up a Debian server with a central Jupyter Lab
# and project-specific, selectable kernels.

# --- Configuration ---
# The project directory where all venvs will be stored.
PROJECT_DIR="/home/$SUDO_USER/projects"

# Ensure the script is run with sudo from a regular user account
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ]; then
  echo "Error: Please run this script from a regular user account using sudo."
  echo "Example: sudo ./setup_project.sh"
  exit 1
fi

# Step 1: Install System Dependencies
echo "🚀 Step 1: Installing system dependencies..."
apt-get update && apt-get full-upgrade -y
apt-get install -y python3-pip python3-full git libopenblas-dev

# Step 2: Install Jupyter Lab for the main user
echo "💻 Step 2: Installing Jupyter Lab for user '$SUDO_USER'..."
sudo -u $SUDO_USER pip install --user --upgrade pip
sudo -u $SUDO_USER pip install --user jupyterlab

# Ensure the user's local bin is in their PATH for future terminal sessions
BASHRC_PATH="/home/$SUDO_USER/.bashrc"
if ! grep -q "$HOME/.local/bin" "$BASHRC_PATH"; then
    echo "Adding ~/.local/bin to PATH in .bashrc"
    echo '' >> $BASHRC_PATH
    echo '# Add user\'s local bin to PATH' >> $BASHRC_PATH
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> $BASHRC_PATH
fi

# Step 3: Get Project Details from User
echo -e "\n📝 Step 3: Please name your new project environment."
echo "   (e.g., 'cats_vs_dogs', 'data_analysis', etc.)"
VENV_NAME=""
while [ -z "$VENV_NAME" ]; do
    read -p "Enter a name for the virtual environment: " VENV_NAME
done
VENV_PATH="$PROJECT_DIR/$VENV_NAME"
echo "Virtual environment will be created at: $VENV_PATH"

# Step 4: Create Venv and Install Project Dependencies + Kernel
echo "🐍 Step 4: Creating venv and installing project packages..."
sudo -u $SUDO_USER mkdir -p $PROJECT_DIR
sudo -u $SUDO_USER python3 -m venv $VENV_PATH

echo "Installing ipykernel and other packages into '$VENV_NAME'..."
sudo -u $SUDO_USER bash -c "source $VENV_PATH/bin/activate && \
pip install --upgrade pip && \
pip install ipykernel tensorflow opencv-python matplotlib kaggle kagglehub numpy Pillow && \
python -m ipykernel install --user --name=\"$VENV_NAME\" --display-name=\"Python ($VENV_NAME)\""

# Step 5: Set up the main Jupyter Lab service
echo "⚙️ Step 5: Setting up the main Jupyter Lab service..."
JUPYTER_EXEC="/home/$SUDO_USER/.local/bin/jupyter-lab"

cat <<EOF > /etc/systemd/system/jupyter.service
[Unit]
Description=Jupyter Lab Server (Central Hub) for $SUDO_USER
After=network.target

[Service]
Type=simple
User=$SUDO_USER
# We now run the user's main jupyter-lab, not one from a venv
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
systemctl restart jupyter.service

echo -e "\n🎉 All done! Your server is set up with the Central Hub model."
echo "You can check the service status with: sudo systemctl status jupyter.service"
echo "Your new kernel '$VENV_NAME' is now available in Jupyter Lab."
