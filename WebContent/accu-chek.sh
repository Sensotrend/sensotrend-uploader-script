#!/bin/bash

################################## FUNCTIONS ##################################

# Post data with curl.
# Configure curl to be silent but capture the HTTP status code to $status.
# Redirect response page to /dev/null.
# Use cookies.
# Expect the path to the file to be posted to be in $file.
# Number of times to retry can be indicated in $retry.
function post {
  status=$(curl -sw "%{http_code}" -o >(cat >/dev/null) -b cookies -c cookies -F "File=@$file;filename=$file" "https://www.sensotrend.fi/api/upload" --retry $retry)
}

# Authenticate the device.
# This call, when successful, returns a cookie that is required to post data.
# Retry 2 times, in case there is an error.
# Capture the final HTTP status code to $status.
function authenticate {
  status=$(curl -sw "%{http_code}" -o >(cat >/dev/null) -b cookies -c cookies -d "filename=$file" "https://www.sensotrend.fi/api/uploader" --retry 2)
}

# Manage the transfer of a file to the server.
# File to be transfred should be in $file variable.
function transfer {
  echo "Transfering $file..."
  post
  if [ "$status" -ge 300 ]; then
    echo "Error sending file, got HTTP status $status"
    if [ "$status" -eq  403 ]; then
      # Not authentiated. Is this a recursive call?
      if [ "$retry" -eq 1 ]; then
        # First time we're here, let's authenticate
        authenticate
        if [ "$status" -lt 300 ]; then
          echo "Authentication successful, got HTTP status $status"
          # Recursive call.
          # Set $retry to 0, so we know not to try authentication again
          # (avoid infinite loop)
          retry=0
          transfer
          return
        else
          echo "Error authenticating, got HTTP status $status"
          # Could indicate to user that there's an error with authentication
        fi
      else
        echo "Authentication was successful, but still got HTTP status 403 Forbidden when posting!"
      fi
    else
      # another error, let's retry a few times
      retry=6
      post
      if [ "$status" -ge 300 ]; then
        echo "Continuous error sending file, last HTTP status $status"
      else
        echo "After retrying, file transfer successful, HTTP status $status"
      fi
    fi
  else
    echo "File transfer successful, HTTP status $status"
  fi
  return $status
}

function mount {
  sudo mount -L SMART_PIX /mnt/accu-chek 2> /dev/null
}

#################################### SCRIPT ###################################

# TODO: First check whether there is a new version of this script available.
# In that case, download, install, and execute it.
# For now, let's just work with this static script.

# Let's start by mounting the device, just in case
mount

# Let's see if we can find the right directory
if [ -d /mnt/accu-chek/REPORT/XML/ ]; then
  # The right directory exists, the device is connected!
  for ((i=0; i<30; i++)) do
    # Get the list of files
    files=$(ls /mnt/accu-chek/REPORT/XML/*.XML 2> /dev/null)
    if [ $? -ne 0 ]; then
      echo "Waiting for XML file..."
      # Wait for 10 seconds...
      sleep 10
      # This also helps to refresh the directory when already mounted
	  # (the file system does not necessarily do that for USB storage devices)
	  mount
    else
	  # There might be several XML files present, let's transfer all of them
      for file in $files; do
        # Allow 1 retry for authentication, signal this in $retry
        retry=1
        transfer
      done
	  # The file was transfered, let's break out from the for loop and quit.
      exit
    fi
  done
  echo "Did not find the XML file in 5 minutes. Shutting down."
  # Shut down to save power.
  sudo shutdown -h now
else
  echo "Error! SMART_PIX device not connected!"
  # Wait for some time, in case the runlevel changes to interactive mode,
  # in which case the daemon should terminate this script.
  sleep 120
  echo "Runlevel not changed in 2 minutes, shutting down."
  sudo shutdown -h now
fi
