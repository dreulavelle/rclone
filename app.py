from pydantic_settings import BaseSettings
from pydantic import Field
import requests
import subprocess


class RcloneConfig(BaseSettings):
    rclone_username: str = Field(..., env="RCLONE_USERNAME")
    rclone_password: str = Field(..., env="RCLONE_PASSWORD")
    RCLONE_URL: str = "https://dav.real-debrid.com"
    RCLONE_CONFIG_PATH: str = Field("/root/.config/rclone/rclone.conf", env="RCLONE_CONFIG_PATH")
    RCLONE_FLAG_VFS_CACHE_MODE: str = Field("full", env="RCLONE_FLAG_VFS_CACHE_MODE")
    RCLONE_FLAG_BUFFER_SIZE: str = Field("32M", env="RCLONE_FLAG_BUFFER_SIZE")
    ICEBERG_MOUNT_PATH: str = Field("/mnt/debrid", env="ICEBERG_MOUNT_PATH")

# Function to encrypt password using rclone obscure
def encrypt_password(password: str) -> str:
    process = subprocess.Popen(['rclone', 'obscure', password],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()
    if process.returncode != 0:
        raise Exception(f"Error encrypting password: {stderr.decode().strip()}")
    return stdout.decode().strip()

# Function to create/update the rclone config file
def create_rclone_config(config: RcloneConfig):
    encrypted_password = encrypt_password(config.rclone_password)

    config_content = f"""
    [debrid]
    type = webdav
    url = {config.RCLONE_URL}
    user = {config.rclone_username}
    pass = {encrypted_password}
    pacer_min_sleep = 0s
    """

    config_path = config.RCLONE_CONFIG_PATH
    try:
        with open(config_path, "w") as file:
            file.write(config_content)
            print(f"Rclone configuration created/updated at {config_path}.")
    except PermissionError as e:
        print(f"Attempted to write to {config_path}. Check permissions or run as a privileged user.")
        print(f"Permission denied: {e}")

def check_rclone_rc_health(username: str, password: str):
    try:
        response = requests.get(f"http://localhost:5572/", auth=(username, password))
        if response.status_code == 200 and response.json().get('result') == "pong":
            print("Rclone RC server is up and running.")
            return True
        else:
            print(f"Rclone RC server is not responding as expected. Status Code: {response.status_code}, Response: {response.text}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"Failed to connect to the Rclone RC server: {e}")
        return False

# Function to start the rclone mount using RC API
def start_rclone_mount(config: RcloneConfig, remote_name: str, mount_point: str):
    url = "http://localhost:5572/mount/mount"
    payload = {
        "fs": f"{remote_name}:",
        "mountPoint": mount_point,
        "vfs-cache-mode": config.RCLONE_FLAG_VFS_CACHE_MODE,
        "buffer-size": config.RCLONE_FLAG_BUFFER_SIZE,
    }
    response = requests.post(url, json=payload)
    
    if response.status_code == 200:
        print(f"Mounted {remote_name} to {mount_point}")
    else:
        print(f"Error mounting: {response.text}")


if __name__ == "__main__":
    try:
        config = RcloneConfig()
        print("Creating rclone config...")
        create_rclone_config(config)
        print("Performing health check on Rclone RC server...")
        check_rclone_rc_health(config.rclone_username, config.rclone_password)
        print("Starting rclone mount...")
        start_rclone_mount(config, "debrid", config.ICEBERG_MOUNT_PATH)
    except Exception as e:
        print(f"An error occurred: {e}")
