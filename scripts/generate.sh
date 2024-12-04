#!/bin/sh
set -e

VERSION="v22.11.0"  # Specify Node.js version

# Default values
TARGET_PLATFORM="linux"
TARGET_ARCH="x64"

# Parse command line arguments
while [ $# -gt 0 ]; do
  case $1 in
		--version)
			VERSION="$2"
			shift
			shift
			;;
    --platform)
      TARGET_PLATFORM="$2"
      shift
      shift
      ;;
    --arch)
      TARGET_ARCH="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 --platform <platform> --arch <arch> [--version <version>]"
      exit 1
      ;;
  esac
done

# Set binary name and extension based on platform
if [ "$TARGET_PLATFORM" = "win" ]; then
  NODE_BINARY="node.exe"
  OUTPUT_BINARY="app-${TARGET_PLATFORM}-${TARGET_ARCH}.exe"
else
  NODE_BINARY="node"
  OUTPUT_BINARY="app-${TARGET_PLATFORM}-${TARGET_ARCH}"
fi

# Generate bundle and blob
npm run build
node --experimental-sea-config sea-config.json

# Create directories
mkdir -p bin/tmp

# Download and extract Node.js binary
NODE_URL="https://nodejs.org/dist/${VERSION}/node-${VERSION}-${TARGET_PLATFORM}-${TARGET_ARCH}.tar.gz"
if [ "$TARGET_PLATFORM" = "win" ]; then
  NODE_URL="https://nodejs.org/dist/${VERSION}/node-${VERSION}-${TARGET_PLATFORM}-${TARGET_ARCH}.zip"
fi

echo "Downloading Node.js from: $NODE_URL"
if [ "$TARGET_PLATFORM" = "win" ]; then
  curl -L "$NODE_URL" -o "bin/tmp/node.zip"
  unzip -q "bin/tmp/node.zip" -d "bin/tmp"
  cp "bin/tmp/node-${VERSION}-${TARGET_PLATFORM}-${TARGET_ARCH}/${NODE_BINARY}" "bin/${OUTPUT_BINARY}"
else
  curl -L "$NODE_URL" | tar xz -C bin/tmp
  cp "bin/tmp/node-${VERSION}-${TARGET_PLATFORM}-${TARGET_ARCH}/bin/${NODE_BINARY}" "bin/${OUTPUT_BINARY}"
fi

rm -rf bin/tmp

# Platform specific preparation
case "$TARGET_PLATFORM" in
  darwin)
    # Remove existing signature on macOS
    codesign --remove-signature "bin/${OUTPUT_BINARY}"

    # Inject the blob with macOS specific options
    npx postject "bin/${OUTPUT_BINARY}" NODE_SEA_BLOB sea-prep.blob \
      --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2 \
      --macho-segment-name NODE_SEA

    # Re-sign the binary
    codesign --sign - "bin/${OUTPUT_BINARY}"
    ;;

  linux)
    # Strip debug symbols on Linux
    strip "bin/${OUTPUT_BINARY}" || true

    # Inject the blob
    npx postject "bin/${OUTPUT_BINARY}" NODE_SEA_BLOB sea-prep.blob \
      --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2
    ;;

  win)
    # Windows specific signing (optional)
    npx postject "bin/${OUTPUT_BINARY}" NODE_SEA_BLOB sea-prep.blob \
      --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2
    # Uncomment if you have a certificate for signing
    # signtool sign /fd SHA256 "bin/${OUTPUT_BINARY}"
    ;;

  *)
    npx postject "bin/${OUTPUT_BINARY}" NODE_SEA_BLOB sea-prep.blob \
      --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2
    ;;
esac

echo "Build complete: bin/${OUTPUT_BINARY}"
