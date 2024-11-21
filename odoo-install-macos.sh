#!/bin/bash

################################################################################
# Installing Odoo on macOS with Homebrew, Python 3.11, and PostgreSQL 14
# Author: Krunal Kanojiya, Rootlevel Innovation Pvt Ltd
# Just clone this repository and run the script. Everything will be installed automatically.
# LICENCE: MIT
################################################################################

# Variables
PYTHON_VERSION="3.11"
PG_VERSION="14"
ODOO_BRANCH="17.0"
ODOO_DIR="odoo-server"  # Odoo server directory
ODOO_CONFIG_FILE="odoo.conf"
ODOO_LOG_FILE="$ODOO_DIR/odoo-server.log"
VENV_DIR="$ODOO_DIR/venv"  # Place the virtual environment inside the odoo-server directory
OE_USER="odoo"
OE_SUPERADMIN="admin"

# Check if Homebrew is installed, if not, install it
if ! command -v brew &> /dev/null
then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ $? -ne 0 ]; then
        echo "Failed to install Homebrew. Exiting."
        exit 1
    fi
else
    echo "Homebrew is installed."
fi

#--------------------------------------------------
# Install Git if not installed
#--------------------------------------------------
if ! command -v git &>/dev/null; then
    echo -e "\n---- Installing Git ----"
    brew install git
else
    echo -e "\n---- Git is installed ----\n"
fi

# Check if the specified Python version is installed
if ! command -v python$PYTHON_VERSION &> /dev/null
then
    echo "Python $PYTHON_VERSION not found. Installing via Homebrew..."
    brew install python@$PYTHON_VERSION
else
    echo "Python $PYTHON_VERSION is already installed."
fi

#--------------------------------------------------
# Install PostgreSQL if not installed
#--------------------------------------------------
if ! command -v psql &>/dev/null; then
    echo -e "\n---- Installing PostgreSQL@${PG_VERSION} ----"
    brew install postgresql@${PG_VERSION}

    # Start PostgreSQL
    brew services start postgresql@${PG_VERSION}
else
    echo -e "\n---- PostgreSQL@${PG_VERSION} is installed ----\n"
fi

# Check if Odoo PostgreSQL user exists, if not, create it
if ! psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$OE_USER'" | grep -q 1; then
    echo "Creating Odoo PostgreSQL user..."
    psql postgres -c "CREATE ROLE $OE_USER WITH SUPERUSER CREATEDB CREATEROLE LOGIN ENCRYPTED PASSWORD '$OE_SUPERADMIN';"
else
    echo "Odoo PostgreSQL user already exists."
fi


# Clone the Odoo repository if it doesn't already exist
if [ -d "$ODOO_DIR" ]; then
    echo "Odoo directory ($ODOO_DIR) already exists. Skipping clone."
else
    echo "Cloning Odoo repository (branch: $ODOO_BRANCH)..."
    git clone --depth 1 --branch $ODOO_BRANCH https://www.github.com/odoo/odoo $ODOO_DIR
    if [ $? -ne 0 ]; then
        echo "Failed to clone Odoo repository. Exiting."
        exit 1
    fi
fi

# Create a virtual environment inside the Odoo directory
echo "Creating virtual environment in $ODOO_DIR/venv..."
python$PYTHON_VERSION -m venv $VENV_DIR

# Activate the virtual environment
echo "Activating virtual environment..."
source $VENV_DIR/bin/activate

# Upgrade pip, setuptools, and wheel
echo "Upgrading pip, setuptools, and wheel..."
pip install --upgrade pip setuptools wheel

# Install additional libraries for Pillow (optional)
echo "Installing libraries for image processing (if required by Pillow)..."
brew install libjpeg libtiff little-cms2 openjpeg webp

# Install Python dependencies from Odoo's requirements.txt
cd $ODOO_DIR
echo "Installing Python dependencies from requirements.txt..."
pip install --no-cache-dir -r requirements.txt
if [ $? -ne 0 ]; then
    echo "Failed to install Python dependencies. Exiting."
    deactivate
    exit 1
fi

# Check if Odoo configuration file exists, and create it if it doesn't
if [ ! -f "$ODOO_CONFIG_FILE" ]; then
    echo "Odoo configuration file not found. Creating $ODOO_CONFIG_FILE..."
    
    # Create the configuration file
    cat <<EOL > "$ODOO_CONFIG_FILE"
[options]
addons_path = addons
db_host = False
db_port = False
db_user = odoo
db_password = False
logfile = /var/log/odoo/odoo-server.log
EOL

    echo "Odoo configuration file created successfully at $ODOO_CONFIG_FILE."
else
    echo "Odoo configuration file already exists at $ODOO_CONFIG_FILE."
fi


# Completion message
echo "Activating the virtual environment...."
source ./venv/bin/activate
echo "Odoo setup completed successfully."

# Run Odoo server
echo "Starting Odoo server..."
python odoo-bin