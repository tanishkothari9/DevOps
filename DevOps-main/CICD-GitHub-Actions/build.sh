#!/bin/bash
# Packages the application into build/ - this folder is uploaded as a GitHub Actions artifact.
set -euo pipefail

echo "================================="
echo "Starting Application Build"
echo "================================="

rm -rf build
mkdir -p build
cp -r app requirements.txt build/
find build -name "__pycache__" -type d -prune -exec rm -rf {} +

cat > build/build-info.txt <<EOF
Application : Session 16 Calculator API
Build Status: SUCCESS
Build Date  : $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Git Commit  : ${GITHUB_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}
Workflow Run: ${GITHUB_RUN_ID:-local}
Runner      : ${RUNNER_NAME:-local machine} (${RUNNER_OS:-$(uname -s)})
EOF

tar -czf build/calculator-app.tar.gz -C build app requirements.txt

echo ""
echo "Build files:"
ls -la build
echo ""
cat build/build-info.txt
echo ""
echo "Build completed successfully."
