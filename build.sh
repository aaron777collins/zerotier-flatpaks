#!/bin/bash

set -e

# Install necessary tools
sudo apt update
sudo apt install -y flatpak flatpak-builder git

# Build flatpak for ZeroTier-One
flatpak-builder --force-clean build-dir-one com.zerotier.one.json
flatpak-builder --repo=repo-one build-dir-one com.zerotier.one.json
tar -czf zerotier-one-flatpak-repo.tar.gz -C repo-one .

# Build flatpak for ZeroTier-GUI
flatpak-builder --force-clean build-dir-gui com.zerotier.gui.json
flatpak-builder --repo=repo-gui build-dir-gui com.zerotier.gui.json
tar -czf zerotier-gui-flatpak-repo.tar.gz -C repo-gui .

echo "Flatpak builds and repo creations complete."
