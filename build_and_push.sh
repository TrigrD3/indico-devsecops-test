#!/bin/bash
# =============================================================================
# Build & Push Image to Docker Hub
# =============================================================================
# This script builds the local Dockerfile and pushes it to Docker Hub
# using your pre-existing Docker CLI authentication session.
#
# Examples of Usage:
#   1. Deploy with a specific repository name and tag (unattended):
#      ./build_and_push.sh -u yourusername -r your-repository-name -t v1.0.0
#
#   2. Interactive Execution (prompts for settings, tags as "latest"):
#      ./build_and_push.sh
# =============================================================================

# Stop script execution immediately if any command fails
set -e

# Configuration variables (overridden by command line flags or environment variables)
DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}"
DOCKERHUB_REPO="${DOCKERHUB_REPO:-}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Display usage guidelines
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -u USERNAME   Docker Hub Username / Organization"
    echo "  -r REPO       Docker Hub Repository Name"
    echo "  -t TAG        Image tag (defaults to 'latest')"
    echo "  -h            Show this helper guidance"
    exit 1
}

# Parse command line flags
while getopts "u:r:t:h" opt; do
    case "$opt" in
        u) DOCKERHUB_USERNAME="$OPTARG" ;;
        r) DOCKERHUB_REPO="$OPTARG" ;;
        t) IMAGE_TAG="$OPTARG" ;;
        h|*) usage ;;
    esac
done

# Interactively prompt for username if not provided
if [ -z "$DOCKERHUB_USERNAME" ]; then
    read -p "Enter Docker Hub Username/Org: " DOCKERHUB_USERNAME
fi

# Interactively prompt for repository name if not provided
if [ -z "$DOCKERHUB_REPO" ]; then
    read -p "Enter Docker Hub Repository Name: " DOCKERHUB_REPO
fi

# Full image name format on Docker Hub: username/repo-name:tag
FULL_IMAGE_NAME="$DOCKERHUB_USERNAME/$DOCKERHUB_REPO:$IMAGE_TAG"

echo ""
echo "========================================================================="
echo "Step 1: Compiling Container Image..."
echo "========================================================================="
echo "Building target image tag: $FULL_IMAGE_NAME"
docker build -t "$FULL_IMAGE_NAME" .

echo ""
echo "========================================================================="
echo "Step 2: Pushing Container to Docker Hub..."
echo "========================================================================="
echo "Pushing using pre-established local Docker login credentials..."
docker push "$FULL_IMAGE_NAME"

echo ""
echo "========================================================================="
echo "Success! Image pushed successfully."
echo "URL: https://hub.docker.com/r/$DOCKERHUB_USERNAME/$DOCKERHUB_REPO"
echo "========================================================================="
