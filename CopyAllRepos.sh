#!/bin/bash
set -e
set -x

# GitHub organization names
SRC_ORG="GomtiGHASDemoOrg1"
DEST_ORG="GomtiGitHubDemos"

# Fetch list of repositories from source organization
echo "Fetching repository list from $SRC_ORG..."
gh repo list $SRC_ORG --limit 1000 --json name -q '.[].name' > repos.txt

# Process each repository
while read repo; do
  echo "Processing $repo"
  
  # Check if the repository exists in the destination organization
  if ! gh repo view "$DEST_ORG/$repo" &>/dev/null; then
    echo "Repository $repo does not exist in $DEST_ORG, creating it..."
    # Create an empty repository in the destination organization and verify it was created
    if ! gh repo create "$DEST_ORG/$repo" --private --description "Copied from $SRC_ORG/$repo"; then
      echo "Error: Failed to create repository $DEST_ORG/$repo. Skipping..."
      continue
    fi
    
    # Verify the repository was created before proceeding
    if ! gh repo view "$DEST_ORG/$repo" &>/dev/null; then
      echo "Error: Repository creation seemed successful but cannot verify $DEST_ORG/$repo exists. Skipping..."
      continue
    fi
    
    # Sleep to allow GitHub to fully propagate the repository creation
    echo "Waiting for GitHub to fully create the repository..."
    sleep 5
  else
    echo "Repository $repo already exists in $DEST_ORG"
  fi
  
  # Clone the source repository as a mirror
  git clone --mirror "git@github.com:$SRC_ORG/$repo.git" || {
    echo "Error: Failed to clone $SRC_ORG/$repo. Skipping..."
    continue
  }
  
  cd "$repo.git"
  
  # Get the HTTPS URL instead of SSH
  REPO_URL=$(gh repo view "$DEST_ORG/$repo" --json url -q '.url')
  
  if [ -z "$REPO_URL" ]; then
    echo "Error: Could not get repository URL. Using default format."
    # Try both formats - first HTTPS then SSH if that fails
    git remote set-url origin "https://github.com/$DEST_ORG/$repo.git"
  else
    # Use the URL from GitHub CLI which should be accurate
    git remote set-url origin "$REPO_URL.git"
  fi
  
  # Push with error handling and retry with alternate URL format if it fails
  if ! git push --mirror; then
    echo "Error: Failed to push with primary URL. Trying SSH format..."
    git remote set-url origin "git@github.com:$DEST_ORG/$repo.git"
    
    if ! git push --mirror; then
      echo "Error: Failed to push with SSH format. Trying HTTPS format..."
      git remote set-url origin "https://github.com/$DEST_ORG/$repo.git"
      
      if ! git push --mirror; then
        echo "Error: All push attempts failed for $DEST_ORG/$repo."
        cd ..
        rm -rf "$repo.git"
        continue
      fi
    fi
  fi
  
  # Clean up
  cd ..
  rm -rf "$repo.git"
  echo "Successfully copied $repo from $SRC_ORG to $DEST_ORG"
done < repos.txt

echo "All repositories have been successfully copied from $SRC_ORG to $DEST_ORG"
