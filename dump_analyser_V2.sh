#!/bin/bash

# Add a pretty welcome message
echo "************************************************************"
echo "*               Welcome to Core Dump Analyzer              *"
echo "*             Please follow the prompts below             *"
echo "*For any issue please user ##yb-support-tools Slack Channel*"
echo "*Feel free to contribute: https://github.com/yugabyte/yb-tools/blob/main/dump_analyser.sh*"
echo "************************************************************"
echo

# Display help section
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: .//dump_analyser.sh <core_file>"
    echo "  -h, --help   Display this help message and exit"
    exit 0
fi


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

# Separator
echo "--------------------------------------------------------"

# Check if the Core file is a valid core dump

file_type=$(file "$file_name")
if echo "$file_type" | grep -q "core file"; then
  echo "Great! The core dump file provided is a valid core dump, proceeding with analysis of core dump."
else
  error_exit "Error: The Core dump file is NOT an ELF core dump, please provide a valid core dump file. Make sure the file IS NOT compressed, if so please extract it and then try again!"
fi


# Extract the yugabyte binary version information from the core dump file

file_output=$(file "$file_name")
yb_executable_path=$(strings "$file_name" | awk "/\/yugabyte\/yb-software\/.*\/bin\// {count++; if (count == 2) {print \$0; exit}}")

if [ -z "$yb_executable_path" ]; then
    yb_executable_path=$(strings "$file_name" | grep -o '/home/yugabyte/[^ ]*/bin/[^ ]*' | head -n 1)
    if [ -z "$yb_executable_path" ]; then
        yb_executable_path=$(strings "$file_name" | grep -o '/home/yugabyte/bin/[^ ]*' | head -n 1)
    fi
fi

#Executable i.e yb-master, yb-tserver, postgres etc by which the core file was generated in the system

yb_executable_process=$(basename "$yb_executable_path")

# Check for yb-controller relates core file, if so exit right away. As YBC core file not supported by this script due to the YBC pck not available publicly to download etc.
if [[ "$yb_executable_process" == "yb-controller"* ]]; then
    echo "The YB-Controller related core file's analysis is not supported."
    echo "You can reach out to agangwar@yugabyte.com to see if there is any alternate way."
    echo "Thanks for your understanding."
    exit 1
fi

# Extract the OS architecture information. Print the OS architecture.

os_architecture="unsupported"

if file "$file_name" | grep -q "x86_64"; then
    os_architecture="x86_64"
elif file "$file_name" | grep -q "aarch64"; then
    os_architecture="aarch64"
else
    # Try to extract architecture from the path
    os_architecture_from_path=$(echo "$yb_executable_path" | grep -oE '(x86_64|aarch64)')
    
    if [ -n "$os_architecture_from_path" ]; then
        os_architecture="$os_architecture_from_path"
    fi
fi

echo "OS architecture is: $os_architecture"

# Extract numeric Yugabyte DB version from the extracted version string above.

yb_db_numeric_version=$(echo "$yb_executable_path" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-b[0-9]+')

error_exit() {
    echo "$1"
    exit 1
}

#The full YB DB version by which the core file created. If yb_db_numeric_version is not provided, prompt the user.
if [ -z "$yb_db_numeric_version" ]; then
    while true; do
        read -p "Please enter the executable version in the <MAJOR.MINOR.PATCH.REVISION-BUILDNumber> format, for example, 2.18.1.0-b84: " yb_db_numeric_version
        if [[ ! $yb_db_numeric_version =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-b[0-9]+$ ]]; then
            echo "Error: Invalid version format. Please enter in the format <MAJOR.MINOR.PATCH.REVISION-BUILDNumber>, for example, 2.18.1.0-b84"
        else
            break
        fi
    done
fi

# Construct yb_db_tar_file based on os_architecture
if [ "$os_architecture" = "x86_64" ]; then
    yb_db_tar_file="yugabyte-$yb_db_numeric_version-linux-$os_architecture.tar.gz"
else
    yb_db_tar_file="yugabyte-$yb_db_numeric_version-el8-$os_architecture.tar.gz"
fi

# Extract numeric Yugabyte DB version for URL
yb_db_numeric_version_without_build=$(echo "$yb_db_numeric_version" | sed 's/-b[0-9]\+$//')

# Separator
echo "--------------------------------------------------------"

# Construct yb_db_tar_url. 
yb_db_tar_url="https://downloads.yugabyte.com/releases/$yb_db_numeric_version_without_build/$yb_db_tar_file"

echo "Downloadable Tar File URL: $yb_db_tar_url"


# Separator
echo "--------------------------------------------------------"

# Download the yb db binary tar file

download_file="$yb_db_tar_file"
yb_db_install_dir="/home/yugabyte/yb-software"

if [ -f "$yb_db_install_dir/$yb_db_tar_file" ]; then
  echo "The file $yb_db_tar_file already exists in $yb_db_install_dir. Skipping the download step."
else
  echo "Downloading the YB version file to $yb_db_install_dir/$yb_db_tar_file"

  # Check if the file exists on the internet
  response_code=$(curl -L --head -w "%{http_code}" "$yb_db_tar_url" -o /dev/null)

  if [ "$response_code" -eq 200 ]; then
    # File exists, proceed with the download
    curl -L -# "$yb_db_tar_url" -o "$yb_db_install_dir/$yb_db_tar_file"
    if [ $? -eq 0 ]; then
      echo "Download of YB version file succeeded."
    else
      error_exit "Error: Download of YB version file failed."
    fi
  else
    error_exit "Error: The YB version file does not exist at $yb_db_tar_url."
  fi
fi


# Separator
echo "--------------------------------------------------------"

# Extract the yb binary tar file in the "/home/yugabyte/yb-software" dir in case file server
yb_db_executable_dir="$yb_db_install_dir/yugabyte-$yb_db_numeric_version_without_build"

if [ -d "$yb_db_executable_dir" ]; then
  echo "$yb_db_executable_dir already exists, not extracting again."
else
  echo "Extracting $yb_db_tar_file in $yb_db_install_dir"
  tar -xzf "$yb_db_install_dir/$yb_db_tar_file" -C $yb_db_install_dir &>/dev/null &
  blinkdots $!
  if [ $? -eq 0 ]; then
    echo "Extracting $yb_db_tar_file completed."
  else
    error_exit "Error: Failed to extract $yb_db_tar_file."
  fi
fi

# Separator
echo "--------------------------------------------------------"

# Execute post install script. This will setup the yb-db executable files to work with core and other cluster related stuff.

post_install="$yb_db_executable_dir/bin/post_install.sh"

if [ -f "$post_install" ]; then
  echo "Executing post_install script to setup the binary as per core dump. Please bear with me!"
  $post_install &>/dev/null &
  blinkdots $!
  if [ $? -eq 0 ]; then
    echo "Post-installation setup completed."
  else
    error_exit "Error: Failed to execute post_install script."
  fi
else
  error_exit "Error: $post_install not found."
fi

#To use the relative yb executable path in the lldb command, let's extrcat this. 
yb_executable_relative_path=$(echo "$yb_executable_path" | sed -E 's|.*/yb-software/yugabyte-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-b[0-9]+-[^/]+/||')

# Use the lldb command with the new input string
# Ask user to enetr available lldb command option for ease.
#The below section is to ask few more user inputs and redirection etc.

# Separator
echo "--------------------------------------------------------"

echo "Select an option for lldb command and press ENTER:"
echo "1. bt"
echo "2. thread backtrace all"
echo "3. Other lldb command"
echo "4. Quit"
read -r option

while [[ ! "$option" =~ ^(1|2|3|4)$ ]]; do
  echo "Error: Invalid option selected. Please select either 1, 2, 3 or 4."
  echo "Select an option for lldb command and press ENTER:"
  echo "1. bt"
  echo "2. thread backtrace all"
  echo "3. Other lldb command"
  echo "4. Quit"
  read -r option
done

# Separator
echo "--------------------------------------------------------"


if [ "$option" == "1" ]; then
  lldb_command="bt"
elif [ "$option" == "2" ]; then
  lldb_command="thread backtrace all"
elif [ "$option" == "3" ]; then
  echo "Enter the lldb command:"
  read -r lldb_command
fi

if [ "$option" != "4" ]; then
  echo "Do you want to redirect the output to a file? (y/n)"
  read -r redirect_output
  while [[ ! "$redirect_output" =~ ^(y|n)$ ]]; do
    echo "Error: Invalid option selected. Please enter either y or n."
    echo "Do you want to redirect the output to a file? (y/n)"
    read -r redirect_output
  done

# Separator
echo "--------------------------------------------------------"


if [ "$redirect_output" == "y" ]; then
  output_file="${file_name}_$(echo "$lldb_command" | tr -s ' ' '_')_analysis.out"
  echo "Output will be saved to $output_file"
  lldb --one-line-before-file "settings append target.exec-search-paths $(find $yb_db_executable_dir -type d | xargs echo)" -f "$yb_db_executable_dir/$yb_executable_relative_path" -c "$file_name" -o "$lldb_command" -o "quit"> "$output_file"
  echo "Analysis complete, the file '$output_file' has been saved."
else
  lldb --one-line-before-file "settings append target.exec-search-paths $(find $yb_db_executable_dir -type d | xargs echo)" -f "$yb_db_executable_dir/$yb_executable_relative_path" -c "$file_name" -o "$lldb_command"
fi
fi
echo "Exiting."
exit 0