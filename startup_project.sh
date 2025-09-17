#!/bin/bash

# A script to set up a Debian server with a central Jupyter Lab
# running from its own dedicated venv, with a 4GB swap file for stability.

# --- Welcome Message ---
echo -e "\n\033[1;34m"
echo "VVVVVVVV           VVVVVVVV                                "
echo "V::::::V           V::::::V                                "
echo "V::::::V           V::::::V                                "
echo "V::::::V           V::::::V                                "
echo " V:::::V           V:::::V EEEEEEEEEEEEEEE  NNNNNNNN        NNNNNNNN VVVVVVVV           VVVVVVVV"
echo "  V:::::V         V:::::V E::::::::::::EEE N:::::::N       N::::::N  V:::::V           V:::::V "
echo "   V:::::V       V:::::V E:::::::::::::::E N::::::::N      N::::::N   V:::::V         V:::::V  "
echo "    V:::::V     V:::::V E:::::EEEEEEEEEEC  N:::::::::N     N::::::N    V:::::V       V:::::V   "
echo "     V:::::V   V:::::V E:::::E             N::::::::::N    N::::::N     V:::::V     V:::::V    "
echo "      V:::::V V:::::V E:::::E              N:::::::::::N   N::::::N      V:::::V   V:::::V     "
echo "       V:::::V:::::V E:::::EEEEEEEEEEC     N::::N:::::::N  N::::::N       V:::::V V:::::V      "
echo "        V:::::::::V E:::::::::::::::E      N::::N N:::::::N N::::::N        V:::::V:::::V       "
echo "         V:::::::V E::::::::::::EEE       N::::N  N:::::::N::::::N         V:::::::::V        "

echo "          V:::::V EEEEEEEEEEEEEEE         N::::N   N::::::::::::N           V:::::::V         "
echo "           V:::V                          N::::N    N:::::::::::N            V:::::V          "
echo "            V:V                           NNNNNN     NNNNNNNNNNNN             V:::V           "
echo -e "\033[0m"
echo -e "\033[1;32m--- Jupyter Lab & Project Environment Setup Script ---\033[0m"
echo "This script will first ask for your project name, then:"
echo "1. Install dependencies and create a 4GB swap file."
echo "2. Set up a dedicated, central environment for Jupyter Lab."
echo "3. Create your named project environment."
echo "4. Register your project environment as a kernel in Jupyter Lab."
echo "----------------------------------------------------"
sleep 2

# --- Configuration ---
PROJECTS_DIR="/home/$SUDO_USER/projects"
JUPYTER_VENV_PATH="/home/$SUDO_USER/jupyter_env"

# Ensure the script is run with sudo from a regular user account
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ]; then
  echo "Error: Please run this script from a regular user account using sudo."
  echo "Example: sudo ./setup.sh"
  exit 1
fi

# Step 1: Get Project Details from User
echo -e "\n📝 Step 1: Please name your new project environment."
echo "   (e.g., 'cats_vs_dogs', 'data_analysis', etc.)"
VENV_NAME=""
while [ -z "$VENV_NAME" ]; do
    read -p "Enter a name for the project's virtual environment: " VENV_NAME
done
PROJECT_VENV_PATH="$PROJECTS_DIR/$VENV_NAME"
echo "Project environment will be created at: $PROJECT_VENV_PATH"

# Step 2: Install System Dependencies & Create Swap File
echo "🚀 Step 2: Installing system dependencies..."
apt-get install -y python3-pip python3-full git libopenblas-dev

echo "💾 Creating and enabling a 4GB swap file for stability..."
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
# Make the swap permanent so it survives reboots
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab

# Step 3: Create and Install Jupyter Lab in its own Venv
echo "💻 Step 3: Creating a dedicated environment for Jupyter Lab..."
sudo -u $SUDO_USER python3 -m venv "$JUPYTER_VENV_PATH"

echo "Installing Jupyter Lab into its environment..."
sudo -u $SUDO_USER bash -c "source \"$JUPYTER_VENV_PATH/bin/activate\" && \
pip install --upgrade pip && \
pip install jupyterlab"

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