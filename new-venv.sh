#!/bin/bash

# A script to create a new project-specific virtual environment
# and register it as a kernel for an existing Jupyter Lab installation.

# --- Welcome Message ---
echo -e "\n\033[1;32m--- Add New Jupyter Kernel Script ---\033[0m"
echo "This script will create a new, isolated Python environment for your project"
echo "and make it available as a kernel in Jupyter Lab."
echo "----------------------------------------------------"
sleep 1

# --- Configuration ---
# All project environments will be stored in this directory
PROJECTS_DIR="$HOME/projects"

# --- Step 1: Get Project Details from User ---
echo -e "\n📝 Step 1: Please name your new project environment."
echo "   (e.g., 'cats_vs_dogs', 'data_analysis', etc.)"
VENV_NAME=""
while [ -z "$VENV_NAME" ]; do
    read -p "Enter a name for the virtual environment: " VENV_NAME
done
PROJECT_VENV_PATH="$PROJECTS_DIR/$VENV_NAME"
echo "Project environment will be created at: $PROJECT_VENV_PATH"

# --- Step 2: Create Venv and Install Packages + Kernel ---
echo -e "\n🐍 Step 2: Creating venv and installing project packages..."
# Create the parent projects directory if it doesn't exist
mkdir -p "$PROJECTS_DIR"
# Create the virtual environment
python3 -m venv "$PROJECT_VENV_PATH"

echo "Installing project packages and registering the kernel..."
# Activate the venv, install packages, and register the kernel in one block
bash -c "source \"$PROJECT_VENV_PATH/bin/activate\" && \
pip install --upgrade pip && \
pip install ipykernel tensorflow opencv-python matplotlib kaggle kagglehub numpy Pillow && \
python -m ipykernel install --user --name=\"$VENV_NAME\" --display-name=\"Python ($VENV_NAME)\""

echo -e "\n🎉 All done! Kernel '$VENV_NAME' has been created and registered."
echo "Restart your Jupyter Lab server and you will see 'Python ($VENV_NAME)' as an option."