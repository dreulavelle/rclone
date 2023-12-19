#!/bin/bash

echo "Starting Container with ${PUID:-1000}:${PGID:-1000} permissions..."

# Check if PUID and PGID are valid integers
if ! [ "$PUID" -eq "$PUID" ] 2> /dev/null; then
    echo "PUID is not a valid integer. Exiting..."
    exit 1
fi

if ! [ "$PGID" -eq "$PGID" ] 2> /dev/null; then
    echo "PGID is not a valid integer. Exiting..."
    exit 1
fi

# Set default values for Rclone environment variables if not provided
: ${RCLONE_USERNAME:=rclone}
: ${RCLONE_PASSWORD:=rclone}

if [ -z "$RCLONE_USERNAME" ]; then
    echo "RCLONE_USERNAME is not set. Exiting..."
    exit 1
fi

if [ -z "$RCLONE_PASSWORD" ]; then
    echo "RCLONE_PASSWORD is not set. Exiting..."
    exit 1
fi

# Export Rclone environment variables
export RCLONE_USERNAME
export RCLONE_PASSWORD

# Set default names for application user and group if not provided
: ${APP_USERNAME:=iceberg}
: ${APP_GROUP:=iceberg}
: ${RCLONE_CONFIG_PATH:=/home/${APP_USERNAME}/.config/rclone/rclone.conf}

# Adjusted user and group creation for Debian
if ! getent group ${PGID} >/dev/null; then
    addgroup --gid $PGID $APP_GROUP > /dev/null
else
    APP_GROUP=$(getent group ${PGID} | cut -d: -f1)
fi

if ! getent passwd ${PUID} >/dev/null; then
    adduser --disabled-password --gecos "" --uid $PUID --ingroup $APP_GROUP $APP_USERNAME > /dev/null
else
    APP_USERNAME=$(getent passwd ${PUID} | cut -d: -f1)
fi

# Create the mount point directory and change ownership
mkdir -p /mnt/debrid
chown ${APP_USERNAME}:${APP_GROUP} /mnt/debrid

# Create the directory and file for Rclone configuration and change ownership
mkdir -p /home/${APP_USERNAME}/.config/rclone
touch ${RCLONE_CONFIG_PATH}
chown -R ${APP_USERNAME}:${APP_GROUP} ${RCLONE_CONFIG_PATH}
chown -R ${APP_USERNAME}:${APP_GROUP} /rclone

# Start Rclone RC server
su -m $APP_USERNAME -c "rclone rcd --rc-no-auth --rc-addr=:5572 --config ${RCLONE_CONFIG_PATH}" &
echo "Rclone RC server started in the background."

# Execute the main Python application
echo "Initialization complete. Starting main application..."
exec su -m $APP_USERNAME -c ". /venv/bin/activate && python3 /rclone/app.py"
