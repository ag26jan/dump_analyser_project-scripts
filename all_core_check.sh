#!/bin/bash

#Function to show blinkdots for various steps in progress when needed in the script.

function blinkdots() {
  local pid=$1
  local delay=0.5
  while kill -0 $pid 2>/dev/null; do
    printf "."
    sleep $delay
    printf "."
    sleep $delay
    printf "."
    sleep $delay
    printf "\b\b\b   \b\b\b"
    sleep $delay
  done
  printf "\n"
}


# Function to display error message and exit

function error_exit() {
  echo "$1"
  exit 1
}

# Enable tab-completion for file names
if [ $# -eq 0 ]; then
  read -e -p "Enter the Core dump file name: " file_name
else
  file_name=$1
fi

# Check if the Core file exists

if [ ! -f "$file_name" ]; then
  error_exit "Error: The file '$file_name' does not exist."
fi

# Check if the Core file is a valid core dump

file_type=$(file "$file_name")
if echo "$file_type" | grep -q "core file"; then
  echo "Great! The core dump file provided is a valid core dump, proceeding with analysis of core dump."
else
  error_exit "Error: The Core dump file is NOT an ELF core dump, please provide a valid core dump file. Make sure the file IS NOT compressed, if so please extract it and then try again!"
fi


# Extract the yugabyte binary version information from the core dump file

file_output=$(file "$file_name")
executable_path=$(strings "$file_name" | awk "/\/yugabyte\/yb-software\/.*\/bin\// {count++; if (count == 2) {print \$0; exit}}")

if [ -z "$executable_path" ]; then
    executable_path=$(strings "$file_name" | grep -o '/home/yugabyte/[^ ]*/bin/[^ ]*' | head -n 1)
    if [ -z "$executable_path" ]; then
        executable_path=$(strings "$file_name" | grep -o '/home/yugabyte/bin/[^ ]*' | head -n 1)
    fi
fi

#Executable i.e yb-master, yb-tserver, postgres etc by which the core file was generated in the system
executable_binary=$(basename "$executable_path")

#The full YB DB version by which the core file created
executable_version=$(echo "$executable_path" | awk -F "/home/yugabyte/yb-software/" '{print $2}' | sed 's/-centos-/-linux-/' | awk -F "/" '{print $1}')

error_exit() {
    echo "$1"
    exit 1
}
