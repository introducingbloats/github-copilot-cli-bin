{
  lib,
  nix-prefetch-scripts,
  writeShellApplication,
  jq,
  coreutils,
  curl,
}:
writeShellApplication {
  name = "github-copilot-cli-bin-update";
  runtimeInputs = [
    jq
    nix-prefetch-scripts
    coreutils
    curl
  ];
  text = ''
    set -euo pipefail

    echo "Fetching latest release from github.com/github/copilot-cli"
    RELEASE=$(curl -sL "https://api.github.com/repos/github/copilot-cli/releases/latest")
    VERSION=$(echo "$RELEASE" | jq -r '.tag_name' | sed 's/^v//')
    echo "Latest version: $VERSION"

    CURRENT_VERSION=$(jq -r '.version' version.json)
    echo "Flake version: $CURRENT_VERSION"
    if [ "$VERSION" = "$CURRENT_VERSION" ]; then
      echo "Version matches current version.json, skipping update"
      exit 0
    fi

    echo "Fetching x86_64-linux tarball and calculating hash"
    X64_URL="https://github.com/github/copilot-cli/releases/download/v$VERSION/copilot-linux-x64.tar.gz"
    X64_SHA256=$(nix-prefetch-url "$X64_URL")
    X64_HASH=$(nix-hash --to-sri --type sha256 "$X64_SHA256")
    echo "x86_64-linux hash: $X64_HASH"

    echo "Fetching aarch64-linux tarball and calculating hash"
    ARM64_URL="https://github.com/github/copilot-cli/releases/download/v$VERSION/copilot-linux-arm64.tar.gz"
    ARM64_SHA256=$(nix-prefetch-url "$ARM64_URL")
    ARM64_HASH=$(nix-hash --to-sri --type sha256 "$ARM64_SHA256")
    echo "aarch64-linux hash: $ARM64_HASH"

    jq --arg version "$VERSION" \
       --arg hash_linux_x64 "$X64_HASH" \
       --arg hash_linux_arm64 "$ARM64_HASH" \
       '.version = $version |
        ."hash-linux-x64" = $hash_linux_x64 |
        ."hash-linux-arm64" = $hash_linux_arm64' \
       version.json > version.json.tmp
    mv version.json.tmp version.json
    echo "done updating version.json with new version and hashes"
  '';
}
