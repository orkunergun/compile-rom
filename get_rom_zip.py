import os
from datetime import datetime

# Get the directory path and ROM name from the environment variables
directory = os.environ.get('TARGET_DIR')
rom_name = os.environ.get('ROM_NAME')

if directory is None or rom_name is None:
    print("Error: TARGET_DIR or ROM_NAME environment variable is not set.")
    exit()

# List files in the directory
files = os.listdir(directory)

# Initialize variables to store the last updated timestamp and corresponding filename
last_updated_timestamp = None
last_updated_filename = None

# Iterate over the files
for filename in files:
    # Check if the file is a zip file and contains the ROM name (case-insensitive)
    if filename.endswith(".zip") and (rom_name.lower() in filename.lower() or rom_name.upper() in filename.upper()):
        # Get the file path
        file_path = os.path.join(directory, filename)
        # Get the last modified timestamp of the file
        modified_timestamp = os.path.getmtime(file_path)
        # Convert timestamp to datetime object
        modified_datetime = datetime.fromtimestamp(modified_timestamp)
        # Update last updated timestamp and filename if this one is newer
        if last_updated_timestamp is None or modified_datetime > last_updated_timestamp:
            last_updated_timestamp = modified_datetime
            last_updated_filename = filename

# Print the last updated zip filename
if last_updated_filename is not None:
    print(os.path.join(directory, last_updated_filename))
else:
    print("No zip files found in the directory that contain the ROM name.")