#!/bin/bash

# Dumper Setup Script
# Installs all required dependencies for Dumper firmware extraction tool
# Copyright (C) 2025 Diwas Neupane (techdiwas)
# SPDX-License-Identifier: GPL-3.0-only
# ----------------------------------------------------------

# ------------------------------
# Define color codes and setup functions
# ------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
NORMAL='\033[0m'

# Clear screen at startup
clear_screen() {
    tput reset 2>/dev/null || clear
}

# Abort function for error handling
abort() {
    [ ! -z "$@" ] && echo -e "${RED}${@}${NORMAL}"
    exit 1
}

# Banner display function
display_banner() {
    echo -e "${GREEN}
    ██████╗░██╗░░░██╗███╗░░░███╗██████╗░███████╗██████╗░
    ██╔══██╗██║░░░██║████╗░████║██╔══██╗██╔════╝██╔══██╗
    ██║░░██║██║░░░██║██╔████╔██║██████╔╝█████╗░░██████╔╝
    ██║░░██║██║░░░██║██║╚██╔╝██║██╔═══╝░██╔══╝░░██╔══██╗
    ██████╔╝╚██████╔╝██║░╚═╝░██║██║░░░░░███████╗██║░░██║
    ╚═════╝░░╚═════╝░╚═╝░░░░░╚═╝╚═╝░░░░░╚══════╝╚═╝░░╚═╝
    ${NORMAL}"
}

# Print status message
print_status() {
    echo -e "${BLUE}>> $1${NORMAL}"
    sleep 1
}

# Print system detected message
print_system_detected() {
    echo -e "${PURPLE}$1 Detected${NORMAL}"
    sleep 1
}

# ------------------------------
# Package installation functions for different OSes
# ------------------------------
install_debian_packages() {
    print_system_detected "Ubuntu/Debian Based Distro"
    print_status "Updating apt repos..."
    sudo apt -y update || abort "Failed to update repositories!"
    
    print_status "Installing required packages..."
    sudo apt install -y unace unrar zip unzip p7zip-full p7zip-rar sharutils rar uudeview mpack arj cabextract rename \
        device-tree-compiler liblzma-dev python3-pip brotli liblz4-tool axel gawk aria2 detox cpio lz4 \
        ccache curl jq python3-dev xz-utils || abort "Failed to install required packages!"
    
    # Install git-lfs separately to handle potential failures
    print_status "Installing git-lfs..."
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
    sudo apt install -y git-lfs || abort "Failed to install git-lfs!"
}

install_fedora_packages() {
    print_system_detected "Fedora Based Distro"
    print_status "Installing required packages..."
    
    # dnf automatically updates repos before installing packages
    sudo dnf install -y unace unrar zip unzip sharutils uudeview arj cabextract file-roller dtc rename \
        python3-pip brotli axel aria2 detox cpio lz4 python3-devel xz-devel p7zip p7zip-plugins git-lfs || \
        abort "Failed to install required packages!"
}

install_arch_packages() {
    print_system_detected "Arch or Arch Based Distro"
    print_status "Installing required packages..."
    
    sudo pacman -Syyu --needed --noconfirm >/dev/null || abort "Failed to update repositories!"
    sudo pacman -Sy --noconfirm unace unrar p7zip sharutils uudeview arj cabextract file-roller dtc perl-rename \
        brotli axel gawk aria2 detox cpio lz4 jq git-lfs || abort "Failed to install required packages!"
}

install_macos_packages() {
    print_system_detected "macOS"
    print_status "Installing required packages..."
    
    brew install protobuf xz brotli lz4 aria2 detox coreutils p7zip gawk git-lfs rename || \
        abort "Failed to install required packages!"
}

# Install UV Python package manager
install_uv() {
    print_status "Installing uv for Python packages..."
    bash -c "$(curl -sL https://astral.sh/uv/install.sh)" || abort "Failed to install uv!"
}

# ------------------------------
# Main function
# ------------------------------
main() {
    # Clear screen and display banner
    clear_screen
    display_banner
    
    # Detect OS and install packages
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt > /dev/null 2>&1; then
            install_debian_packages
        elif command -v dnf > /dev/null 2>&1; then
            install_fedora_packages
        elif command -v pacman > /dev/null 2>&1; then
            install_arch_packages
        else
            abort "Unsupported Linux distribution!"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        install_macos_packages
    else
        abort "Unsupported operating system: $OSTYPE"
    fi
    
    # Install UV
    install_uv
    
    # Success message
    echo -e "${GREEN}Setup Complete!${NORMAL}"
    exit 0
}

# Run main function
main
