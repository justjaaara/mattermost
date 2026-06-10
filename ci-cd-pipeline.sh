#!/bin/bash
set -e

# Determine workspace path
if [ -d "/workspace" ]; then
    WORKSPACE="/workspace"
else
    WORKSPACE="/home/felipe/Documents/GitRepos/mattermost"
fi

echo "========================================="
echo "CI/CD Pipeline - Mattermost Toggle Reviewer"
echo "========================================="
echo "Workspace: $WORKSPACE"

# Stage 1: Checkout
echo "[STAGE 1] Checkout"
cd $WORKSPACE
git log --oneline -3

# Stage 2: Build & Test (using Docker container with build tools)
echo "[STAGE 2] Build Server"
docker run --rm -v $WORKSPACE:/app -w /app/server -e IS_CI=true golang:1.22-bookworm bash -c "
    apt-get update && apt-get install -y make
    make modules-tidy
    make setup-go-work
    make generated
    go test ./channels/app -run TestContentFlagging -v -coverprofile=coverage_app.out -timeout 10m
    go test ./public/model -run TestContentFlagging -v -coverprofile=coverage_model.out -timeout 10m
    tail -n +2 coverage_model.out >> coverage_app.out 2>/dev/null || true
    sed -i 's|github.com/mattermost/mattermost/server/v8/|server/|g' coverage_app.out
    sed -i 's|github.com/mattermost/mattermost/server/public/|server/public/|g' coverage_app.out
    go tool cover -func=coverage_app.out | grep content_flagging || true
"

# Stage 3: SonarQube Analysis
echo "[STAGE 3] SonarQube Analysis"
docker run --rm --network mattermost_mattermost-network \
  -v $WORKSPACE:/usr/src \
  -e SONAR_HOST_URL="http://sonarqube:9000" \
  -e SONAR_TOKEN="squ_76af51993ab2c2caa3694a8cf289e140642c2900" \
  sonarsource/sonar-scanner-cli

# Stage 4: Docker Build
echo "[STAGE 4] Docker Build"
docker build -t mattermost-toggle-reviewer:latest $WORKSPACE

# Stage 5: Deploy (simulated)
echo "[STAGE 5] Deploy"
echo "Deployment step completed (simulated)"

echo "========================================="
echo "Pipeline completed successfully!"
echo "========================================="
