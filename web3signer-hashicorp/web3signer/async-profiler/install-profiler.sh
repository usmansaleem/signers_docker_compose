#!/bin/bash
# async-profiler/install-profiler.sh

set -eo pipefail  # Strict error handling

# Detect architecture via Docker (converts amd64→x64, aarch64→arm64)
ARCH=$(docker system info -f '{{.Architecture}}' |
       sed 's/amd64/x64/;s/aarch64/arm64/')

VERSION="4.0"
URL="https://github.com/async-profiler/async-profiler/releases/download/v$VERSION/async-profiler-$VERSION-linux-$ARCH.tar.gz"

echo "→ Detected architecture: $ARCH"
echo "↓ Downloading async-profiler v$VERSION..."
mkdir -p async-profiler
curl -L "$URL" | tar -xz -C . --strip-components=1
echo "✓ Installed to ./async-profiler/bin/asprof"