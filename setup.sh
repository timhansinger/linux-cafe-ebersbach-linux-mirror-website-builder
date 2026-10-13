#!/bin/bash

# ==================================================
# GLOBAL VARIABLE
# ==================================================
LINUX_MIRROR="linux-mirror"

# ==================================================
# DEFAULT CONFIGURATIONS (Flags)
# ==================================================
DRY_RUN=false
SKIP_CLEANUP=false
DRY_FLAG=""

# ==================================================
# HELP MENU FUNCTION
# ==================================================
show_help() {
  echo "Usage: $0 [COMMAND] [OPTIONS]"
  echo ""
  echo "Linux Cafe Automated Deployment Script"
  echo "Runs user tweaks natively and escalates to sudo automatically for system tasks."
  echo ""
  echo "Commands:"
  echo "  run                  Execute the actual deployment process."
  echo ""
  echo "Options (only applicable with the 'run' command):"
  echo "  -d, --dry-run        Simulate the upgrade process. Does not download"
  echo "                       or install any packages to the drive."
  echo "  -s, --skip-cleanup   Prevents the script from removing the temporary"
  echo "                       mirror list and preference files upon exit."
  echo "  -h, --help           Display this help screen and exit."
  echo ""
  echo "Examples:"
  echo "  $0                  # Shows this help menu"
  echo "  $0 run              # Executes the full deployment"
  echo "  $0 run --dry-run    # Simulates the deployment safely"
  exit 0
}

# Helper function to extract value safely
extract_value() {
    local file="$1"
    local pattern="$2"
    local varname="$3"
    
    # Check if file exists and is readable
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        declare -g "$varname="
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        echo "Error: Cannot read file: $file" >&2
        declare -g "$varname="
        return 1
    fi
    
    # Extract first match, trim whitespace, assign to global variable
    local value
    value=$(grep -m 1 "^${pattern}=" "$file" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '[:space:]')
    
    if [[ -z "$value" ]]; then
        echo "Error: Pattern '$pattern' not found or empty in $file" >&2
        declare -g "$varname="
        return 1
    fi
    
    declare -g "$varname=$value"
    return 0
}

# ==================================================
# SUBCOMMAND VALIDATION
# ==================================================
# If no arguments are passed, or the first argument isn't "run", show help.
if [ $# -eq 0 ] || [ "$1" != "run" ]; then
  # If they specifically asked for help via -h or --help, show it too
  show_help
fi

# Remove "run" from the argument list so we can parse the remaining options
shift

# ==================================================
# ARGUMENT PARSING LOOP (For everything after 'run')
# ==================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)         show_help ;;
    -d|--dry-run)      DRY_RUN=true; DRY_FLAG="-s"; shift ;;
    -s|--skip-cleanup) SKIP_CLEANUP=true; shift ;;
    *) echo "Unknown option: $1"; echo "Use $0 --help to see available options."; exit 1 ;;
  esac
done

# ==================================================
# 1. INITIALIZE SUDO ELEVATION UPFRONT
# ==================================================
echo "Please authenticate to initialize administrative privileges for system updates:"
sudo -v || exit 1

# Keep the sudo timestamp alive in the background (kills itself when script ends)
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# ==================================================
# 2. RUN USER SPECIFIC SETTINGS (No sudo needed)
# ==================================================
#echo "=================================================="
#echo " Applying User-Specific Settings for: $USER"
#echo "=================================================="

# Example: Configure Neovim to use system clipboard for this specific user
#echo "--> Configuring Neovim clipboard..."
#mkdir -p "$HOME/.config/nvim"
#cat << 'EOF' > "$HOME/.config/nvim/init.lua"
#vim.opt.clipboard = "unnamed,unnamedplus"
#EOF

# Example: Set custom desktop wallpaper or panel preferences via gsettings
#echo "--> Setting default desktop preferences..."
#gsettings set org.cinnamon.desktop.background picture-uri "file:///usr/share/backgrounds/linuxmint/default.jpg" 2>/dev/null

# ==================================================
# 3. RUN SYSTEM WIDE SETTINGS (Prefix commands with sudo)
# ==================================================
echo "=================================================="
echo " Starting Dynamic Mirror Injection (System Level) "
echo "=================================================="

# Show active flags to the technician
[ "$DRY_RUN" = true ] && echo "--> MODE: [DRY-RUN / SIMULATION]"
[ "$SKIP_CLEANUP" = true ] && echo "--> SETTING: [SKIP CLEANUP ACTIVE]"

# Define paths
ORIGINAL_SOURCES="/etc/apt/sources.list.d/official-package-repositories.list"
BACKUP_SOURCES="/etc/apt/sources.list.d/official-package-repositories.list.bak"
TEMPORARY_MIRROR_LIST="/tmp/00-local-mirror.list"
TEMP_SOURCES="/etc/apt/sources.list.d/00-local-mirror.list"

# Verify official list exists
if [ ! -f "$ORIGINAL_SOURCES" ]; then
  echo "Error: $ORIGINAL_SOURCES not found!"
  exit 1
fi

# Dynamically generate your local mirror file
echo "--> Creating local mirror paths automatically..."
echo ""

# Extract codenames
extract_value "/etc/linuxmint/info" "CODENAME" "codename"
extract_value "/etc/upstream-release/lsb-release" "DISTRIB_CODENAME" "basecodename"

# Only proceed if we have codenames loaded
if [[ -z "$codename" ]] || [[ -z "$basecodename" ]]; then
    echo "Error: Could not determine codename(s)." >&2
    exit 1
fi

# Verify mintsources config directory exists
MINTCONFIG_DIR="/usr/share/mintsources/${codename}"
if [[ ! -d "$MINTCONFIG_DIR" ]]; then
    echo "Error: Mintsources config directory not found: $MINTCONFIG_DIR" >&2
    exit 1
fi

MINTCONFIG_FILE="${MINTCONFIG_DIR}/mintsources.conf"

# Extract mirrors if config exists
if [[ -f "$MINTCONFIG_FILE" ]]; then
    extract_value "$MINTCONFIG_FILE" "default" "mirror"
    extract_value "$MINTCONFIG_FILE" "base_default" "basemirror"
else
    echo "Error: Mintsources config not found: $MINTCONFIG_FILE" >&2
    exit 1
fi

# Only proceed if we have mirrors loaded
if [[ -z "$mirror" ]] || [[ -z "$basemirror" ]]; then
    echo "Error: Could not determine mirror(s)." >&2
    exit 1
fi

# Handle optionalcomponents
optionalcomponents=""

# Optional: Verification output (remove in production or make conditional)
echo "Configuration loaded:"
echo "  codename: $codename"
echo "  basecodename: $basecodename"
echo "  mirror: $mirror"
echo "  basemirror: $basemirror"
echo "  optionalcomponents: $optionalcomponents"
echo ""

# Process template
TEMPLATE_FILE="/usr/share/mintsources/${codename}/official-package-repositories.list"
#OUTPUT_FILE="/etc/apt/sources.list.d/linuxmint-${codename}.list"
#OUTPUT_FILE="/tmp/00-local-mirror.list"

[[ -f "$TEMPLATE_FILE" ]] || { echo "Error: Template not found: $TEMPLATE_FILE" >&2; exit 1; }

# Substitute variables using sed
sed -E \
    -e 's|\$mirror|'"$mirror"'|g' \
    -e 's|\$basemirror|'"$basemirror"'|g' \
    -e 's|\$codename|'"$codename"'|g' \
    -e 's|\$basecodename|'"$basecodename"'|g' \
    -e 's|\$optionalcomponents|'"$optionalcomponents"'|g' \
    -e "s|https?://|http://${LINUX_MIRROR}/|g" \
    "$TEMPLATE_FILE" > "$TEMPORARY_MIRROR_LIST"

if [[ ! -f "$TEMPORARY_MIRROR_LIST" ]] || [[ ! -s "$TEMPORARY_MIRROR_LIST" ]]; then
    echo "Error: Failed to create temporary mirror list file" >&2
    exit 1
fi

sudo mv -f "$TEMPORARY_MIRROR_LIST" "$TEMP_SOURCES"

if [[ ! -f "$TEMP_SOURCES" ]] || [[ ! -s "$TEMP_SOURCES" ]]; then
    echo "Error: Failed to create temporary sources file" >&2
    exit 1
fi

echo "Successfully created: $TEMP_SOURCES"
echo ""
cat "$TEMP_SOURCES"

# HIDE THE OFFICIAL LIST (Move it so APT ignores it entirely)
# This guarantees APT can ONLY talk to linux-mirror for system packages
sudo mv "$ORIGINAL_SOURCES" "$BACKUP_SOURCES"

# Run system updates using our background-authenticated sudo
echo "--> Synchronizing package indexes from local mirror..."
sudo apt-get update

echo "--> Upgrading system packages..."
sudo apt-get dist-upgrade $DRY_FLAG -y

# ==================================================
# 4. CONDITIONAL CLEAN UP
# ==================================================
echo "--> Restoring customer machine back to default official repositories..."
# Bring the official file back
sudo mv "$BACKUP_SOURCES" "$ORIGINAL_SOURCES"

if [ "$SKIP_CLEANUP" = true ]; then
  echo "--> [SKIPPED] Cleanup step skipped by request. Linux-mirror configurations left intact."
  echo "    Files left on disk:"
  echo "    - $TEMP_SOURCES"
else
  # Delete the temporary local mirror file
  sudo rm -f "$TEMP_SOURCES"

  # Re-index so the customer's cache points home
  echo "--> Re-indexing database back to official web paths..."
  sudo apt-get update
fi

# TODO: sudo apt autoremove -y

echo "=================================================="
echo " Done! All user configurations and updates applied. "
echo "=================================================="
