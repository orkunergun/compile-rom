import os
import re
from datetime import datetime

# Get the directory path from the environment variable
directory = os.environ.get('TARGET_DIR')

if directory is None:
    print("Error: TARGET_DIR environment variable is not set.")
    exit()

# List files in the directory
files = os.listdir(directory)

# Define a regex pattern to match timestamps in the filenames
pattern = r'\d{8}-\d{4}'

# Initialize variables to store the closest timestamp and corresponding filename
closest_timestamp = None
closest_filename = None

# Get current timestamp
current_time = datetime.now()

# Iterate over the files
for filename in files:
    # Check if the filename matches the pattern
    match = re.search(pattern, filename)
    if match:
        # Extract the timestamp from the filename
        timestamp_str = match.group()
        # Convert timestamp string to datetime object
        timestamp = datetime.strptime(timestamp_str, "%Y%m%d-%H%M")
        # Calculate the time difference
        time_difference = abs(current_time - timestamp)
        # Update closest timestamp and filename if this one is closer
        if closest_timestamp is None or time_difference < closest_timestamp:
            closest_timestamp = time_difference
            closest_filename = filename

# Remove every character after the zip extension
closest_filename = closest_filename.split(".zip")[0] + ".zip"

# Get the path of the closest zip file
closest_filename = os.path.join(directory, closest_filename)

# Print the closest zip filename
print(closest_filename)
