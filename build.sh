#!/bin/bash

set -e

LOGFILE="logs/build.log"
CURRENT_DIRECTORY=$(pwd)
LOG_FILE_PATH="$CURRENT_DIRECTORY/logs/build.log"
mkdir -p logs
echo " \n" > $LOG_FILE_PATH

log() {
    echo "$(date) - $1" | tee -a $LOG_FILE_PATH
}

log "Installing necessary tools"
sudo apt update | tee -a $LOG_FILE_PATH
sudo apt install -y flatpak flatpak-builder git wget jq curl | tee -a $LOG_FILE_PATH

log "Installing Rust and Cargo"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y | tee -a $LOG_FILE_PATH
source $HOME/.cargo/env

log "Adding Flathub repository and installing required runtimes"
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo | tee -a $LOG_FILE_PATH
sudo flatpak install -y flathub org.freedesktop.Platform//21.08 org.freedesktop.Sdk//21.08 | tee -a $LOG_FILE_PATH

log "Creating build directory"
mkdir -p build | tee -a $LOG_FILE_PATH
cd build

log "Fetching the latest ZeroTier-One release"
ZTO_URL=$(curl -s https://api.github.com/repos/zerotier/ZeroTierOne/releases/latest | jq -r '.tarball_url')
log "ZeroTier-One URL: $ZTO_URL"
wget -O zerotier-one-latest.tar.gz $ZTO_URL | tee -a $LOG_FILE_PATH
log "Downloaded ZeroTier-One tarball"

log "Listing contents of the tarball"
tar -tzf zerotier-one-latest.tar.gz | tee -a $LOG_FILE_PATH || { log "Failed to list tarball contents"; exit 1; }

log "Extracting ZeroTier-One tarball"
tar -xzf zerotier-one-latest.tar.gz | tee -a $LOG_FILE_PATH || { log "Failed to extract tarball"; exit 1; }
ZTO_DIR=$(tar -tzf zerotier-one-latest.tar.gz | head -1 | cut -f1 -d"/")
ZTO_SHA256=$(sha256sum zerotier-one-latest.tar.gz | cut -d ' ' -f 1)
log "ZeroTier-One directory: $ZTO_DIR"
log "ZeroTier-One SHA256: $ZTO_SHA256"

log "Creating Flatpak manifest for ZeroTier-One"
cat > com.zerotier.one.json <<EOL
{
    "app-id": "com.zerotier.one",
    "runtime": "org.freedesktop.Platform",
    "runtime-version": "21.08",
    "sdk": "org.freedesktop.Sdk",
    "command": "zerotier-one",
    "build-options": {
        "env": {
            "CARGO_HOME": "/app/.cargo",
            "PATH": "/app/.cargo/bin:/usr/bin:/bin"
        }
    },
    "modules": [
        {
            "name": "zerotier-one",
            "buildsystem": "simple",
            "build-commands": [
                "make",
                "mkdir -p /app/bin",
                "cp zerotier-one /app/bin/"
            ],
            "sources": [
                {
                    "type": "archive",
                    "url": "$ZTO_URL",
                    "sha256": "$ZTO_SHA256",
                    "dest-filename": "zerotier-one-latest.tar.gz"
                }
            ]
        }
    ]
}
EOL

log "Building Flatpak for ZeroTier-One"
flatpak-builder --force-clean build-dir-one com.zerotier.one.json 2>&1 | tee -a $LOG_FILE_PATH || { log "Failed to build ZeroTier-One"; exit 1; }
log "Built ZeroTier-One"
flatpak-builder --repo=repo-one build-dir-one com.zerotier.one.json 2>&1 | tee -a $LOG_FILE_PATH || { log "Failed to build ZeroTier-One repo"; exit 1; }
log "Built ZeroTier-One repo"
tar -czf zerotier-one-flatpak-repo.tar.gz -C repo-one . || { log "Failed to package ZeroTier-One Flatpak"; exit 1; }
log "Packaged ZeroTier-One Flatpak"

log "Fetching the latest ZeroTier-GUI release"
ZTG_URL=$(curl -s https://api.github.com/repos/tralph3/ZeroTier-GUI/releases/latest | jq -r '.tarball_url')
log "ZeroTier-GUI URL: $ZTG_URL"
wget -O zerotier-gui-latest.tar.gz $ZTG_URL | tee -a $LOG_FILE_PATH
log "Downloaded ZeroTier-GUI tarball"
tar -tzf zerotier-gui-latest.tar.gz | tee -a $LOG_FILE_PATH || { log "Failed to list tarball contents"; exit 1; }
log "Extracted ZeroTier-GUI tarball"
tar -xzf zerotier-gui-latest.tar.gz | tee -a $LOG_FILE_PATH || { log "Failed to extract tarball"; exit 1; }
ZTG_DIR=$(tar -tzf zerotier-gui-latest.tar.gz | head -1 | cut -f1 -d"/")
ZTG_SHA256=$(sha256sum zerotier-gui-latest.tar.gz | cut -d ' ' -f 1)
log "ZeroTier-GUI directory: $ZTG_DIR"
log "ZeroTier-GUI SHA256: $ZTG_SHA256"

log "Creating Flatpak manifest for ZeroTier-GUI"
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
                "python setup.py install --prefix=/app"
            ],
            "sources": [
                {
                    "type": "archive",
                    "url": "$ZTG_URL",
                    "sha256": "$ZTG_SHA256",
                    "dest-filename": "zerotier-gui-latest.tar.gz"
                }
            ]
        }
    ]
}
EOL

log "Building Flatpak for ZeroTier-GUI"
flatpak-builder --force-clean build-dir-gui com.zerotier.gui.json 2>&1 | tee -a $LOG_FILE_PATH || { log "Failed to build ZeroTier-GUI"; exit 1; }
log "Built ZeroTier-GUI"
flatpak-builder --repo=repo-gui build-dir-gui com.zerotier.gui.json 2>&1 | tee -a $LOG_FILE_PATH || { log "Failed to build ZeroTier-GUI repo"; exit 1; }
log "Built ZeroTier-GUI repo"
tar -czf zerotier-gui-flatpak-repo.tar.gz -C repo-gui . || { log "Failed to package ZeroTier-GUI Flatpak"; exit 1; }
log "Packaged ZeroTier-GUI Flatpak"

log "Flatpak builds and repo creations complete"
