#!/bin/bash

set -e

# Install necessary tools
sudo apt update
sudo apt install -y flatpak flatpak-builder git wget jq

# Add Flathub repository and install required runtimes
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install -y flathub org.freedesktop.Platform//21.08 org.freedesktop.Sdk//21.08

# Create a build directory
mkdir -p build
cd build

# Fetch the latest ZeroTier-One release
ZTO_URL=$(curl -s https://api.github.com/repos/zerotier/ZeroTierOne/releases/latest | jq -r '.tarball_url')
wget -O zerotier-one-latest.tar.gz $ZTO_URL
tar -xzf zerotier-one-latest.tar.gz
ZTO_DIR=$(tar -tzf zerotier-one-latest.tar.gz | head -1 | cut -f1 -d"/")
ZTO_SHA256=$(sha256sum zerotier-one-latest.tar.gz | cut -d ' ' -f 1)

# Create Flatpak manifest for ZeroTier-One
cat > com.zerotier.one.json <<EOL
{
    "app-id": "com.zerotier.one",
    "runtime": "org.freedesktop.Platform",
    "runtime-version": "21.08",
    "sdk": "org.freedesktop.Sdk",
    "command": "zerotier-one",
    "modules": [
        {
            "name": "zerotier-one",
            "buildsystem": "simple",
            "build-commands": [
                "cd $ZTO_DIR",
                "make",
                "mkdir -p /app/bin",
                "cp zerotier-one /app/bin/"
            ],
            "sources": [
                {
                    "type": "archive",
                    "url": "$ZTO_URL",
                    "sha256": "$ZTO_SHA256"
                }
            ]
        }
    ]
}
EOL

# Build flatpak for ZeroTier-One
flatpak-builder --force-clean build-dir-one com.zerotier.one.json
flatpak-builder --repo=repo-one build-dir-one com.zerotier.one.json
tar -czf zerotier-one-flatpak-repo.tar.gz -C repo-one .

# Fetch the latest ZeroTier-GUI release
ZTG_URL=$(curl -s https://api.github.com/repos/tralph3/ZeroTier-GUI/releases/latest | jq -r '.tarball_url')
wget -O zerotier-gui-latest.tar.gz $ZTG_URL
tar -xzf zerotier-gui-latest.tar.gz
ZTG_DIR=$(tar -tzf zerotier-gui-latest.tar.gz | head -1 | cut -f1 -d"/")
ZTG_SHA256=$(sha256sum zerotier-gui-latest.tar.gz | cut -d ' ' -f 1)

# Create Flatpak manifest for ZeroTier-GUI
cat > com.zerotier.gui.json <<EOL
{
    "app-id": "com.zerotier.gui",
    "runtime": "org.freedesktop.Platform",
    "runtime-version": "21.08",
    "sdk": "org.freedesktop.Sdk",
    "command": "zerotier-gui",
    "modules": [
        {
            "name": "zerotier-gui",
            "buildsystem": "simple",
            "build-commands": [
                "cd $ZTG_DIR",
                "python setup.py install --prefix=/app"
            ],
            "sources": [
                {
                    "type": "archive",
                    "url": "$ZTG_URL",
                    "sha256": "$ZTG_SHA256"
                }
            ]
        }
    ]
}
EOL

# Build flatpak for ZeroTier-GUI
flatpak-builder --force-clean build-dir-gui com.zerotier.gui.json
flatpak-builder --repo=repo-gui build-dir-gui com.zerotier.gui.json
tar -czf zerotier-gui-flatpak-repo.tar.gz -C repo-gui .

echo "Flatpak builds and repo creations complete."
