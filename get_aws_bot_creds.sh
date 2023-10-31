#!/usr/bin/env bash
#

# creates a bot user if it doesn't exist
# deletes existing access key if it does exist
# creates a new access key and saves it to /tmp

set -eu -o pipefail
echo "Grabbing user info from AWS"
caller_data=$(aws sts get-caller-identity)
user_name=$(cut -d: -f2 <<<$(jq -r .UserId <<<$caller_data ))
account=$(cut -d: -f2 <<<$(jq -r .Account <<<$caller_data ))
if [[ -z $user_name ]]; then
  echo "No user found from aws, confirm you have AWS SSO configured with a default profile " \
    "or export AWS_PROFILE to the profile to use"
  echo "Be sure you have configured AWS SSO with awscliv2 before running this script."
  exit 1
fi
bot_name="${user_name}_bot"
creds_path="$HOME/.yugabyte/${bot_name}_access_key.json"
mkdir -p $(dirname $creds_path)
echo "bot credentials will be saved to ${creds_path}"

if ! aws iam get-user --user-name ${bot_name} &> /dev/null; then
  echo "${bot_name} doesn't exist yet, creating"
  if ! out=$(aws iam create-user --user-name ${bot_name} 2>&1 ); then
    echo "Error creating bot user ${bot_name}"
    echo $out
    exit 1
  fi

  if ! out=$(aws iam add-user-to-group --user-name ${bot_name} --group-name yugadev 2>&1 ); then
    echo "Error adding bot user ${bot_name} group 'yugadev'"
    echo $out
    exit 1
  fi
fi

# Check for existing access key
old_key=$(jq -r '.AccessKeyMetadata[0].AccessKeyId // empty' <<<$(aws iam list-access-keys --user-name ${bot_name}))
if [[ -n $old_key ]]; then
  echo "Found existing key ${old_key}"
  read -p "Delete it and issue new cred? (y/N) " -n 1 -r
  echo    # move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    aws iam delete-access-key --user-name ${bot_name} --access-key-id ${old_key}
  else
    echo "Not deleting existing credentials, exiting."
    exit 0
  fi
fi

# Create the new access key.  Ensure it isn't world readable.
umask 077
aws iam create-access-key --user-name ${bot_name} | tee ${creds_path}
