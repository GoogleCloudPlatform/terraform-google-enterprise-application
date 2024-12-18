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
      personal_token=$(cat /dev/random | tr -dc "[:alnum:]" | head -c 20)
      gitlab-rails runner "token = User.find_by_username('root').personal_access_tokens.create(scopes: ['api', 'read_api', 'read_user'], name: 'Automation token', expires_at: 365.days.from_now); token.set_token('$personal_token'); token.save!"
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
