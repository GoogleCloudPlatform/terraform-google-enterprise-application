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
while [[ true ]]; do
  RESPONSE_BODY=$(curl $URL)

  if echo "$RESPONSE_BODY" | grep -q "You are .*redirected"; then
      echo "GitLab initialized and ready to sign-in"
      GITLAB_INITIAL_PASSWORD=$(cat /etc/gitlab/initial_root_password  | grep "Password:" | awk '{ print $2 }')
      echo "grant_type=password&username=root&password=$GITLAB_INITIAL_PASSWORD" > auth.txt
      access_token=$(curl -k --data "@auth.txt" --request POST "$URL/oauth/token" | jq -r '.access_token')
      personal_token=$(curl -k --request POST --header "Authorization: Bearer $access_token" --data "name=mytoken" --data "scopes[]=api" "$URL/api/v4/users/1/personal_access_tokens" -k | jq -r '.token')
      printf $personal_token | gcloud secrets create gitlab-pat-created-from-vm --project=$PROJECT_ID --data-file=-
      break
  else
      echo "GitLab is not ready for sign-in operations. Waiting 5 seconds and will try again."
      echo "Command Output:"
      echo "$RESPONSE_BODY"
      sleep 5
  fi

done

