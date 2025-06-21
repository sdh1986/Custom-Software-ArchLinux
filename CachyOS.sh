#!/bin/bash

# Define ANSI color codes
NC='\033[0m'         # No Color / Reset
RED='\033[0;31m'     # Red for failure/errors
GREEN='\033[0;32m'   # Green for success
YELLOW='\033[0;33m' # Yellow for warnings/skipping
BLUE='\033[0;34m'   # Blue for information/checking
CYAN='\033[0;36m'   # Cyan for ongoing processes/installing

# Function to check if a package is installed
is_package_installed() {
    pacman -Q "$1" &> /dev/null
    return $?
}

# Function to check if a service is enabled and active
is_service_enabled_and_active() {
    systemctl is-enabled "$1" &> /dev/null && systemctl is-active "$1" &> /dev/null
    return $?
}

# Function to check if a user is in a group
is_user_in_group() {
    groups "$1" | grep -qw "$2"
    return $?
}

# --- Update Pacman mirrorlist ---
echo -e "${BLUE}Updating Pacman mirrorlist and synchronizing databases...${NC}"
sudo pacman -Syyu --noconfirm
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Pacman mirrorlist updated and databases synchronized successfully.${NC}"
else
    echo -e "${RED}Failed to update Pacman mirrorlist or synchronize databases. Please check your internet connection and pacman configuration.${NC}"
    exit 1
fi

echo "---"

# --- Install Fcitx5 packages ---
echo -e "${BLUE}Checking Fcitx5 package installation...${NC}"
if ! is_package_installed "fcitx5"; then
    echo -e "${YELLOW}Fcitx5 packages not found. Installing...${NC}"
    sudo pacman -S --noconfirm fcitx5 fcitx5-configtool fcitx5-qt fcitx5-chinese-addons
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Fcitx5 packages installed successfully.${NC}"
    else
        echo -e "${RED}Failed to install Fcitx5 packages. Please check for errors or try updating your mirrorlist again.${NC}"
    fi
else
    echo -e "${YELLOW}Fcitx5 packages already installed. Skipping.${NC}"
fi

echo "---"

# --- Configure Fcitx5 environment variables in /etc/environment ---
echo -e "${BLUE}Checking Fcitx5 environment variables in /etc/environment...${NC}"
ENVIRONMENT_FILE="/etc/environment"
FCITX_VARS='
# Fcitx5
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
'

if grep -q "GTK_IM_MODULE=fcitx" "$ENVIRONMENT_FILE" && \
   grep -q "QT_IM_MODULE=fcitx" "$ENVIRONMENT_FILE" && \
   grep -q "XMODIFIERS=@im=fcitx" "$ENVIRONMENT_FILE" && \
   grep -q "SDL_IM_MODULE=fcitx" "$ENVIRONMENT_FILE" && \
   grep -q "GLFW_IM_MODULE=ibus" "$ENVIRONMENT_FILE"; then
    echo -e "${YELLOW}Fcitx5 environment variables already present in ${ENVIRONMENT_FILE}. Skipping.${NC}"
else
    echo -e "${CYAN}Adding Fcitx5 environment variables to ${ENVIRONMENT_FILE}...${NC}"
    echo "$FCITX_VARS" | sudo tee -a "$ENVIRONMENT_FILE" > /dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Fcitx5 environment variables added successfully to ${ENVIRONMENT_FILE}.${NC}"
    else
        echo -e "${RED}Failed to add Fcitx5 environment variables to ${ENVIRONMENT_FILE}. Please check for errors.${NC}"
    fi
fi

echo "---"

# --- Install Virt-manager and QEMU packages ---
echo -e "${BLUE}Checking Virt-manager and QEMU package installation...${NC}"
if ! is_package_installed "virt-manager"; then
    echo -e "${YELLOW}Virt-manager not found. Installing virtualization packages...${NC}"
    sudo pacman -Syu --needed --noconfirm virt-manager qemu-full libvirt edk2-ovmf dnsmasq vde2 bridge-utils openbsd-netcat swtpm
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Virtualization packages installed successfully.${NC}"
    else
        echo -e "${RED}Failed to install virtualization packages. Please check for errors.${NC}"
    fi
else
    echo -e "${YELLOW}Virt-manager and related packages already installed. Skipping.${NC}"
fi

echo "---"

# --- Enable and start libvirtd.service ---
echo -e "${BLUE}Checking libvirtd service status...${NC}"
if ! is_service_enabled_and_active "libvirtd.service"; then
    echo -e "${YELLOW}libvirtd.service is not enabled or active. Enabling and starting...${NC}"
    sudo systemctl enable --now libvirtd.service
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}libvirtd.service enabled and started successfully.${NC}"
    else
        echo -e "${RED}Failed to enable and start libvirtd.service. Please check for errors.${NC}"
    fi
else
    echo -e "${YELLOW}libvirtd.service is already enabled and active. Skipping.${NC}"
fi

echo "---"

# --- Modify libvirtd.conf ---
echo -e "${BLUE}Checking libvirtd.conf configuration...${NC}"
LIBVIRTD_CONF="/etc/libvirt/libvirtd.conf"
CONFIG_CHANGED=0

# Check unix_sock_group
if grep -qE '^unix_sock_group = "libvirt"$' "$LIBVIRTD_CONF"; then
    echo -e "${YELLOW}unix_sock_group already configured in libvirtd.conf. Skipping.${NC}"
else
    echo -e "${CYAN}Modifying unix_sock_group in libvirtd.conf...${NC}"
    sudo sed -i 's/#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/' "$LIBVIRTD_CONF"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}unix_sock_group modified successfully.${NC}"
        CONFIG_CHANGED=1
    else
        echo -e "${RED}Failed to modify unix_sock_group.${NC}"
    fi
fi

# Check unix_sock_rw_perms
if grep -qE '^unix_sock_rw_perms = "0770"$' "$LIBVIRTD_CONF"; then
    echo -e "${YELLOW}unix_sock_rw_perms already configured in libvirtd.conf. Skipping.${NC}"
else
    echo -e "${CYAN}Modifying unix_sock_rw_perms in libvirtd.conf...${NC}"
    sudo sed -i 's/#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/' "$LIBVIRTD_CONF"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}unix_sock_rw_perms modified successfully.${NC}"
        CONFIG_CHANGED=1
    else
        echo -e "${RED}Failed to modify unix_sock_rw_perms.${NC}"
    fi
fi

if [ "$CONFIG_CHANGED" -eq 0 ]; then
    echo -e "${YELLOW}libvirtd.conf already configured as expected. Skipping changes.${NC}"
else
    echo -e "${GREEN}libvirtd.conf changes applied.${NC}"
fi

echo "---"

# --- Add current user to libvirt and kvm groups ---
CURRENT_USER=$(whoami)
echo -e "${BLUE}Checking user group memberships for ${CURRENT_USER}...${NC}"

# Add to libvirt group
if ! is_user_in_group "$CURRENT_USER" "libvirt"; then
    echo -e "${CYAN}Adding ${CURRENT_USER} to libvirt group...${NC}"
    sudo usermod -aG libvirt "$CURRENT_USER"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${CURRENT_USER} added to libvirt group successfully. You might need to log out and back in for changes to take effect.${NC}"
    else
        echo -e "${RED}Failed to add ${CURRENT_USER} to libvirt group.${NC}"
    fi
else
    echo -e "${YELLOW}${CURRENT_USER} is already in libvirt group. Skipping.${NC}"
fi

# Add to kvm group
if ! is_user_in_group "$CURRENT_USER" "kvm"; then
    echo -e "${CYAN}Adding ${CURRENT_USER} to kvm group...${NC}"
    sudo usermod -aG kvm "$CURRENT_USER"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${CURRENT_USER} added to kvm group successfully. You might need to log out and back in for changes to take effect.${NC}"
    else
        echo -e "${RED}Failed to add ${CURRENT_USER} to kvm group.${NC}"
    fi
else
    echo -e "${YELLOW}${CURRENT_USER} is already in kvm group. Skipping.${NC}"
fi

# --- Modify qemu.conf ---
echo -e "${BLUE}Checking qemu.conf configuration...${NC}"
QEMU_CONF="/etc/libvirt/qemu.conf"
QEMU_CONFIG_CHANGED=0

# Check user setting
if grep -qE "^user = \"$CURRENT_USER\"$" "$QEMU_CONF"; then
    echo -e "${YELLOW}user setting already configured in qemu.conf. Skipping.${NC}"
else
    echo -e "${CYAN}Modifying user setting in qemu.conf...${NC}"
    sudo sed -i "s/#user = \"libvirt-qemu\"/user = \"$CURRENT_USER\"/" "$QEMU_CONF"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}user setting modified successfully.${NC}"
        QEMU_CONFIG_CHANGED=1
    else
        echo -e "${RED}Failed to modify user setting.${NC}"
    fi
fi

echo "---"

# Check group setting
if grep -qE '^group = "wheel"$' "$QEMU_CONF"; then
    echo -e "${YELLOW}group setting already configured in qemu.conf. Skipping.${NC}"
else
    echo -e "${CYAN}Modifying group setting in qemu.conf...${NC}"
    sudo sed -i 's/#group = "libvirt-qemu"/group = "kvm"/' "$QEMU_CONF"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}group setting modified successfully.${NC}"
        QEMU_CONFIG_CHANGED=1
    else
        echo -e "${RED}Failed to modify group setting.${NC}"
    fi
fi

if [ "$QEMU_CONFIG_CHANGED" -eq 0 ]; then
    echo -e "${YELLOW}qemu.conf already configured as expected. Skipping changes.${NC}"
else
    echo -e "${GREEN}qemu.conf changes applied.${NC}"
fi

echo "---"

# --- Install Timeshift ---
echo -e "${BLUE}Checking Timeshift installation...${NC}"
if ! is_package_installed "timeshift"; then
    echo -e "${YELLOW}Timeshift not found. Installing...${NC}"
    sudo pacman -S --noconfirm timeshift
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Timeshift installed successfully.${NC}"
    else
        echo -e "${RED}Failed to install Timeshift. Please check for errors.${NC}"
    fi
else
    echo -e "${YELLOW}Timeshift already installed. Skipping.${NC}"
fi

echo "---"

# --- Install Backintime ---
echo -e "${BLUE}Checking Backintime installation...${NC}"
if ! is_package_installed "backintime"; then
    echo -e "${YELLOW}Backintime not found. Installing...${NC}"
    paru -S --noconfirm backintime
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backintime installed successfully.${NC}"
    else
        echo -e "${RED}Failed to install Backintime. Please check for errors.${NC}"
    fi
else
    echo -e "${YELLOW}Backintime already installed. Skipping.${NC}"
fi

echo "---"

# --- Install Bitwarden ---
echo -e "${BLUE}Checking Bitwarden installation...${NC}"
if ! is_package_installed "bitwarden"; then
    echo -e "${YELLOW}Bitwarden not found. Installing...${NC}"
    sudo pacman -S --noconfirm bitwarden
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Bitwarden installed successfully.${NC}"
    else
        echo -e "${RED}Failed to install Bitwarden. Please check for errors.${NC}"
    fi
else
    echo -e "${YELLOW}Bitwarden already installed. Skipping.${NC}"
fi

echo "---"

# --- Install Brave ---
echo -e "${BLUE}Checking Brave installation...${NC}"
if ! is_package_installed "brave"; then
    echo -e "${YELLOW}Brave not found. Installing...${NC}"
    sudo pacman -S --noconfirm brave
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Brave installed successfully.${NC}"
    else
        echo -e "${RED}Failed to install Brave. Please check for errors.${NC}"
    fi
else
    echo -e "${YELLOW}Brave already installed. Skipping.${NC}"
fi

echo "---"

# --- Install OBS ---
echo -e "${BLUE}Checking OBS installation...${NC}"
if ! is_package_installed "obs-studio"; then
    echo -e "${YELLOW}OBS not found. Installing...${NC}"
    sudo pacman -S --noconfirm obs-studio
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OBS installed successfully.${NC}"
    else
        echo -e "${RED}Failed to install OBS. Please check for errors.${NC}"
    fi
else
    echo -e "${YELLOW}OBS already installed. Skipping.${NC}"
fi

echo "---"

# --- Install BTOP ---
echo -e "${BLUE}Checking BTOP installation...${NC}"
if ! is_package_installed "btop"; then
    echo -e "${YELLOW}BTOP not found. Installing...${NC}"
    sudo pacman -S --noconfirm btop
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}BTOP installed successfully.${NC}"
    else
        echo -e "${RED}Failed to install BTOP. Please check for errors.${NC}"
    fi
else
    echo -e "${YELLOW}BTOP already installed. Skipping.${NC}"
fi

echo "---"

# --- Install ClashVergeRev ---
:<<Clash echo -e "${BLUE}Checking ClashVergeRev installation...${NC}"
if ! is_package_installed "clash-verge-rev-bin"; then
    echo -e "${YELLOW}ClashVergeRev not found. Installing...${NC}"
    paru -S --noconfirm clash-verge-rev-bin
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}ClashVergeRev installed successfully.${NC}"
    else
        echo -e "${RED}Failed to install ClashVergeRev. Please check for errors.${NC}"
    fi
else
    echo -e "${YELLOW}ClashVergeRev already installed. Skipping.${NC}"
fi
Clash

echo "---"
echo -e "${GREEN}Script execution complete.${NC}"
echo -e "${YELLOW}Remember to log out and log back in for group changes and environment variables to take full effect.${NC}"