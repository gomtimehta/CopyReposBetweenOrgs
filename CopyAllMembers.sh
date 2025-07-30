#!/bin/bash
# Script to copy members from one GitHub organization to another

SOURCE_ORG="GomtiGitHubDemos"
DEST_ORG="GomtiGHASDemoOrg1"

# Authenticate with GitHub CLI first (if not already)
# gh auth login

# Get all members from source org and invite them to destination org
gh api --paginate /orgs/$SOURCE_ORG/members | jq -r '.[].login' | while read username; do
  echo "Inviting $username to $DEST_ORG..."
  gh api -X PUT /orgs/$DEST_ORG/memberships/$username
done

echo "Done! Members have been invited to $DEST_ORG"
