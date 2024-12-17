#!/bin/bash

# GitLab Installation
apt-get update
apt-get install -y curl openssh-server ca-certificates tzdata perl jq
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | bash
apt-get install gitlab-ee


# Retrieve values from Metadata Server
EXTERNAL_IP=$(curl http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")
PROJECT_ID=$(curl http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")

# Host GitLab on External IP with Lets-Encrypt SSL Certificate
URL="https://$EXTERNAL_IP.nip.io"
echo "external_url \"$URL\"" > /etc/gitlab/gitlab.rb && gitlab-ctl reconfigure


# Wait for the server to handle authentication requests
for i in {1..100}; do
  RESPONSE_BODY=$(curl $URL)

  if echo "$RESPONSE_BODY" | grep -q "You are .*redirected"; then
      echo "GitLab initialized and ready to handle sign-in interactions"
      sleep 5
      # Sign-in to gitlab
      GITLAB_INITIAL_PASSWORD=$(cat /etc/gitlab/initial_root_password  | grep "Password:" | awk '{ print $2 }')
      echo "grant_type=password&username=root&password=$GITLAB_INITIAL_PASSWORD" > auth.txt
      access_token=$(curl -k --data "@auth.txt" --request POST "$URL/oauth/token" | tee /tmp/token_curl_stdout.txt | jq -r '.access_token')
      if [[ $access_token == "null" ]]; then
        echo "Authentication failed, will reconfigure the gitlab server and try again. More information about the request:"
        cat /tmp/token_curl_stdout.txt
        gitlab-ctl reconfigure
        continue
      fi
      echo "access_token=$(echo $access_token | head -c 6)*********"
      # Create a personal access token and store in secret manager
      personal_token=$(curl -k --request POST --header "Authorization: Bearer $access_token" --data "name=mytoken" --data "scopes[]=api" --data "scopes[]=read_api" --data "scopes[]=read_user" "$URL/api/v4/users/1/personal_access_tokens" -k | jq -r '.token')
      echo "personal_token=$(echo $personal_token | head -c 6)*********"
      printf $personal_token | gcloud secrets create gitlab-pat-from-vm --project=$PROJECT_ID --data-file=-
      break
  else
      echo "GitLab is not ready for sign-in operations. Waiting 5 seconds and will try again."
      echo "Command Output:"
      echo "$RESPONSE_BODY"
      sleep 5
  fi

done
