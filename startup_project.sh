#!/bin/bash

# A script to set up a Debian server with a central Jupyter Lab
# running from its own dedicated venv, with a 4GB swap file for stability.
#
# USAGE:
# This script must be run by a regular user with sudo privileges.
# It performs system-wide actions (installing software, creating services)
# as root, but creates all user-specific files and environments in the
# home directory of the user who calls the script.
#
# Example: sudo ./setup_jupyter.sh

# --- Welcome Message ---
echo -e "\n\033[1;34m"
echo "VVVVVVVV            VVVVVVVV                                  "
echo "V::::::V            V::::::V                                  "
echo "V::::::V            V::::::V                                  "
echo "V::::::V            V::::::V                                  "
echo " V:::::V             V:::::V EEEEEEEEEEEEEEE   NNNNNNNN        NNNNNNNNVVVVVVVV            VVVVVVVV"
echo "  V:::::V           V:::::V E::::::::::::EEE  N:::::::N       N::::::N V:::::V            V:::::V "
echo "   V:::::V         V:::::V E:::::::::::::::E N::::::::N      N::::::N  V:::::V          V:::::V  "
echo "    V:::::V       V:::::V E:::::EEEEEEEEEEC  N:::::::::N     N::::::N   V:::::V        V:::::V   "
echo "     V:::::V     V:::::V E:::::E             N::::::::::N    N::::::N    V:::::V      V:::::V    "
echo "      V:::::V   V:::::V E:::::E              N:::::::::::N   N::::::N     V:::::V    V:::::V     "
echo "       V:::::V V:::::V E:::::EEEEEEEEEEC      N::::N:::::::N  N::::::N      V:::::V  V:::::V      "
echo "        V:::::::::V E:::::::::::::::E       N::::N N:::::::N N::::::N       V:::::V V:::::V       "
echo "         V:::::::V E::::::::::::EEE        N::::N  N:::::::N::::::N        V:::::::::V        "
echo "          V:::::V EEEEEEEEEEEEEEE         N::::N   N::::::::::::N           V:::::::V         "
echo "           V:::V                          N::::N    N:::::::::::N            V:::::V          "
echo "            V:V                           NNNNNN     NNNNNNNNNNNN             V:::V           "
echo -e "\033[0m"
echo -e "\033[1;32m--- Jupyter Lab & Project Environment Setup Script ---\033[0m"
echo "This script will first ask for your project name, then:"
echo "1. Install dependencies and create a 4GB swap file."
echo "2. Set up a dedicated, central environment for Jupyter Lab."
echo "3. Create your named project environment."
echo "4. Optionally clone a Git repo and copy a specific notebook."
echo "5. Configure the firewall and start the Jupyter service."
echo "----------------------------------------------------"
sleep 2

# --- Pre-flight Checks and Configuration ---

# Ensure the script is run with sudo from a regular user account
if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ]; then
  echo "Error: Please run this script from a regular user account using sudo."
  echo "Example: sudo ./setup_jupyter.sh"
  exit 1
fi

# Define user and home directory for all operations
# This ensures all files are created for the user who ran sudo, not for root.
readonly CURRENT_USER="$SUDO_USER"
readonly USER_HOME=$(eval echo ~$CURRENT_USER) # Robustly get home directory

# Define paths within the user's home directory
readonly PROJECTS_DIR="$USER_HOME/projects"
readonly JUPYTER_VENV_PATH="$USER_HOME/jupyter_env"
readonly PIP_TMP_DIR="$USER_HOME/pip_tmp"


# --- Step 1: Get Project Details from User ---
echo -e "\n📝 Step 1: Please name your new project environment."
echo "   (e.g., 'cats_vs_dogs', 'data_analysis', etc.)"
VENV_NAME=""
while [ -z "$VENV_NAME" ]; do
    read -p "Enter a name for the project's virtual environment: " VENV_NAME
done
readonly PROJECT_VENV_PATH="$PROJECTS_DIR/$VENV_NAME"
echo "Project environment will be created at: $PROJECT_VENV_PATH"
sleep 1


# --- Step 2: Install System Dependencies & Create Swap File (Requires Root) ---
echo -e "\n🚀 Step 2: Installing system dependencies (requires root)..."
# Add ufw to the list of packages to install
apt-get update && apt-get full-upgrade -y
apt-get install -y python3-pip python3-full git libopenblas-dev ufw

if [ ! -f /swapfile ]; then
    echo "💾 Creating and enabling a 4GB swap file for stability..."
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    # Make the swap permanent so it survives reboots
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
else
    echo "💾 Swap file already exists. Skipping creation."
fi


# --- Step 3: Create Central Jupyter Lab Environment (As User) ---
echo -e "\n💻 Step 3: Creating a dedicated environment for Jupyter Lab..."
# Run the following commands as the regular user to ensure correct ownership
sudo -u "$CURRENT_USER" python3 -m venv "$JUPYTER_VENV_PATH"

echo "Installing Jupyter Lab into its environment..."
sudo -u "$CURRENT_USER" bash -c "source \"$JUPYTER_VENV_PATH/bin/activate\" && \
pip install --upgrade pip && \
pip install jupyterlab"


# --- Step 4: Create Project Venv and Register it as a Kernel (As User) ---
echo -e "\n🐍 Step 4: Creating project venv and installing packages..."
# Create directories as the user to ensure correct ownership
sudo -u "$CURRENT_USER" mkdir -p "$PIP_TMP_DIR"
sudo -u "$CURRENT_USER" mkdir -p "$PROJECTS_DIR"
sudo -u "$CURRENT_USER" python3 -m venv "$PROJECT_VENV_PATH"

echo "Installing project packages and registering the kernel..."
# Use a temporary directory on the main disk to avoid filling up /tmp
# Then, activate the venv, install packages, and register it with Jupyter
sudo -u "$CURRENT_USER" bash -c "source \"$PROJECT_VENV_PATH/bin/activate\" && \
export TMPDIR=\"$PIP_TMP_DIR\" && \
pip install --upgrade pip && \
pip install ipykernel tensorflow opencv-python matplotlib kaggle kagglehub numpy Pillow && \
python -m ipykernel install --user --name=\"$VENV_NAME\" --display-name=\"Python ($VENV_NAME)\""


# --- Step 5: Clone Git Repository and Copy Notebook (As User) ---
echo -e "\n📂 Step 5: Clone a Git repository (optional)."
read -p "Enter the Git repository URL to clone (or press Enter to skip): " GIT_REPO_URL

if [ -n "$GIT_REPO_URL" ]; then
    # Create a unique name for the clone directory based on the repo URL
    CLONE_DIR_NAME=$(basename "$GIT_REPO_URL" .git)
    CLONE_PATH="$PROJECTS_DIR/$CLONE_DIR_NAME"

    echo "Cloning into '$CLONE_PATH'..."
    # Run the clone as the user to ensure correct ownership
    sudo -u "$CURRENT_USER" git clone "$GIT_REPO_URL" "$CLONE_PATH"

    # Now, find and copy the specific notebook
    echo "Searching for 'cat-vd-dog.ipynb' in the cloned repository..."
    # Use find to locate the file, -print to show path, -quit to stop after first match
    NOTEBOOK_PATH=$(find "$CLONE_PATH" -name "cat-vd-dog.ipynb" -print -quit)

    if [ -n "$NOTEBOOK_PATH" ]; then
        echo "✅ Found notebook. Copying to the main projects directory..."
        sudo -u "$CURRENT_USER" cp "$NOTEBOOK_PATH" "$PROJECTS_DIR/"
        echo "Notebook 'cat-vd-dog.ipynb' is now available in your Jupyter Lab projects folder."
    else
        echo "⚠️  Warning: Could not find 'cat-vd-dog.ipynb' in the repository."
        echo "The full repository has been cloned into the '$CLONE_DIR_NAME' folder for you to access."
    fi
else
    echo "Skipping Git clone."
fi


# --- Step 6: Configure Firewall and Set up Service (Requires Root) ---
echo -e "\n⚙️ Step 6: Configuring firewall and setting up Jupyter Lab service..."

echo "🔥 Configuring firewall to allow Jupyter traffic on port 8888..."
ufw allow 8888/tcp
# The --force flag enables ufw without a y/n prompt
ufw --force enable

# The service definition needs to be created by root
JUPYTER_EXEC="$JUPYTER_VENV_PATH/bin/jupyter-lab"
cat <<EOF > /etc/systemd/system/jupyter.service
[Unit]
Description=Jupyter Lab Server (for user $CURRENT_USER)
After=network.target

[Service]
Type=simple
# Crucially, run the service as the user, not as root
User=$CURRENT_USER
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

# Add a short delay to allow the service to initialize before we check its status
sleep 3


# --- Step 7: Final Cleanup and Instructions ---
echo "🧹 Cleaning up temporary pip directory..."
sudo -u "$CURRENT_USER" rm -rf "$PIP_TMP_DIR"

echo -e "\n📊 Checking the status of the Jupyter service..."
# --no-pager shows the full output without needing to scroll, -l shows full lines
systemctl status jupyter.service --no-pager -l

# Get the server's primary IP address to show the user
IP_ADDR=$(hostname -I | awk '{print $1}')

echo -e "\n\033[1;32m🎉 All done! Your Jupyter Lab server should be ready.\033[0m"
echo "You can access it at: \033[1mhttp://$IP_ADDR:8888\033[0m"
echo "Your project kernel '$VENV_NAME' is available inside Jupyter Lab."
echo -e "\nTo get the login token, copy and paste the following command as your regular user:"
echo "----------------------------------------------------------------"
echo -e "  \033[1;33m~/jupyter_env/bin/jupyter server list\033[0m"
echo "----------------------------------------------------------------"

