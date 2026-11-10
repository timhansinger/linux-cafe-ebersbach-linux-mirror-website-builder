#!/bin/bash

# ==================================================
# GLOBAL VARIABLE
# ==================================================
LINUX_MIRROR="linux-mirror.local"

MINT_MIRROR="[trusted=yes] http://${LINUX_MIRROR}/mint"
UBUNTU_MIRROR="[trusted=yes] http://${LINUX_MIRROR}/ubuntu"

MINT_MIRROR_LOCAL="https://ftp-stud.hs-esslingen.de/pub/Mirrors/packages.linuxmint.com"
UBUNTU_MIRROR_LOCAL="http://ftp-stud.hs-esslingen.de/ubuntu"

# ==================================================
# DEFAULT CONFIGURATIONS (Flags)
# ==================================================
DRY_RUN=false
RUN_POST_INSTALL_SCRIPT=false
DRY_FLAG=""
POST_INSTALL_DRY_FLAG=""

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
  echo "  only-post-install    Only execute the post-install-script."
  echo ""
  echo "Options (only applicable with the 'run' command):"
  echo "  -d, --dry-run        Simulate the upgrade process. Does not download"
  echo "                       or install any packages to the drive."
  echo "  -p, --post-install   Also run the post install script."
  echo "  -h, --help           Display this help screen and exit."
  echo ""
  echo "Examples:"
  echo "  $0                   # Shows this help menu"
  echo "  $0 run               # Executes the full deployment"
  echo "  $0 run --dry-run     # Simulates the deployment safely"
  echo "  $0 run -p            # Executes the full deployment including the post-install"
  echo "  $0 only-post-install # Only executes the post-install-script"
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

echo "$1"
# ==================================================
# SUBCOMMAND VALIDATION
# ==================================================
# If no arguments are passed, or the first argument isn't either "run" or "only-post-install", show help.
if [ $# -eq 0 ] || { [ "$1" != "run" ] && [ "$1" != "only-post-install" ]; }; then
  # If they specifically asked for help via -h or --help, show it too
  show_help
fi

run_post_install_script() {
  sudo apt-get install -y git && \
    tmp_repo="$(mktemp -d -p "${TMPDIR:-/tmp}" lcafe.XXXXXXXX)" && \
    bash -c "trap 'trap - EXIT INT TERM; rm -rf -- $tmp_repo' EXIT INT TERM && \
    git clone --depth 1 https://github.com/timhansinger/linux-cafe-ebersbach-linux-mint-cinnamon-post-install-script $tmp_repo && \
    bash $tmp_repo/run.sh $POST_INSTALL_DRY_FLAG"
}

if [ "$1" = "only-post-install" ]; then
  run_post_install_script
  exit
fi

# Remove "run" from the argument list so we can parse the remaining options
shift

# ==================================================
# ARGUMENT PARSING LOOP (For everything after 'run')
# ==================================================
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)         show_help ;;
    -d|--dry-run)      DRY_RUN=true; DRY_FLAG="-s"; POST_INSTALL_DRY_FLAG="--dry-run"; shift ;;
    -p|--post-install) RUN_POST_INSTALL_SCRIPT=true; shift ;;
    *) echo "Unknown option: $1"; echo "Use $0 --help to see available options."; exit 1 ;;
  esac
done

# ==================================================
# INITIALIZE SUDO ELEVATION UPFRONT
# ==================================================
echo "Please authenticate to initialize administrative privileges for system updates:"
sudo -v || exit 1

# Keep the sudo timestamp alive in the background (kills itself when script ends)
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# ==================================================
# RUN SYSTEM WIDE SETTINGS (Prefix commands with sudo)
# ==================================================
echo "=================================================="
echo " Starting Dynamic Mirror Injection (System Level) "
echo "=================================================="

# Show active flags to the technician
[ "$DRY_RUN" = true ] && echo "--> MODE: [DRY-RUN / SIMULATION]"
[ "$RUN_POST_INSTALL_SCRIPT" = true ] && echo "--> MODE: [ALSO RUN POST INSTALLATION SCRIPT]"

# Define paths
ORIGINAL_SOURCES="/etc/apt/sources.list.d/official-package-repositories.list"
BACKUP_SOURCES="$ORIGINAL_SOURCES.bak"
TEMP_SOURCES="/etc/apt/sources.list.d/00-local-mirror.list"

cleanup() {
  local code=$?
  trap - EXIT INT TERM # avoid re-entry

  echo -e "\nCleaning up (code $code, signal: ${SIGNAL:-none})"

  # If we use DRY_RUN or if we exited with an error we restore the original repositories
  if [[ "$DRY_RUN" == true ]] || (( code != 0 )); then
    echo "--> Restoring customer machine back to previous repositories..."
    # Bring the official file back
    sudo mv "$BACKUP_SOURCES" "$ORIGINAL_SOURCES" 2>/dev/null
  fi

  # Delete the temporary local mirror file
  sudo rm -f "$TEMP_SOURCES" 2>/dev/null

  # Re-index so the customer's cache points home
  echo "--> Re-indexing database..."
  sudo apt-get update

  # This is needed so that the repository sources are correctly shown in Update Manager
  echo "--> Re-starting Update Manager..."
  pkill -f mintupdate && sleep 5; mintupdate > /dev/null 2>&1
  echo "--> Re-starting Update Manager..."

  echo "=================================================="
  echo " Finished! Cleanup performed. "
  echo "=================================================="

  exit "$code"
}

# Verify official list exists
if [ ! -f "$ORIGINAL_SOURCES" ]; then
  echo "Error: $ORIGINAL_SOURCES not found!"
  exit 1
fi

# Dynamically generate your local mirror file
echo "--> Creating local mirror paths automatically..."
echo ""

# Extract codenames
extract_value "/etc/linuxmint/info" "CODENAME" "CODENAME"
extract_value "/etc/upstream-release/lsb-release" "DISTRIB_CODENAME" "BASECODENAME"

# Only proceed if we have codenames loaded
if [[ -z "$CODENAME" ]] || [[ -z "$BASECODENAME" ]]; then
    echo "Error: Could not determine codename(s)." >&2
    exit 1
fi

# Optional: Verification output
echo "Configuration loaded:"
echo "  codename: $CODENAME"
echo "  basecodename: $BASECODENAME"
echo ""

# Process template
TEMPLATE_FILE="/usr/share/mintsources/${CODENAME}/official-package-repositories.list"

[[ -f "$TEMPLATE_FILE" ]] || { echo "Error: Template not found: $TEMPLATE_FILE" >&2; exit 1; }

generate_mirror_list() {
    local mint_mirror \
          ubuntu_mirror \
          template_file \
          temporary_output_file="/tmp/00-local-mirror.list" \
          output_file \
          codename \
          basecodename \
          optionalcomponents="" \
          replace_security=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mint-mirror)        mint_mirror="$2"; shift 2 ;;
            --ubuntu-mirror)      ubuntu_mirror="$2"; shift 2 ;;
            --template)           template_file="$2"; shift 2 ;;
            --temporary-output)   temporary_output_file="$2"; shift 2 ;;
            --output)             output_file="$2"; shift 2 ;;
            --basecodename)       basecodename="$2"; shift 2 ;;
            --codename)           codename="$2"; shift 2 ;;
            --optionalcomponents) optionalcomponents="$2"; shift 2 ;;
            --replace-security)   replace_security=true; shift ;;
            *) echo "Unknown option: $1" >&2; return 1 ;;
        esac
    done

    local sed_args=(
        -E
        -e "s|\\\$mirror|${mint_mirror}|g"
        -e "s|\\\$basemirror|${ubuntu_mirror}|g"
        -e "s|\\\$codename|${codename}|g"
        -e "s|\\\$basecodename|${basecodename}|g"
        -e "s|\\\$optionalcomponents|${optionalcomponents}|g"
    )

    if [[ "$replace_security" == "true" ]]; then
        sed_args+=(-e "s|https?://security.ubuntu.com/ubuntu/?|${ubuntu_mirror}|g")
    fi

    sed "${sed_args[@]}" "$template_file" > "$temporary_output_file"

    if [[ ! -f "$temporary_output_file" ]] || [[ ! -s "$temporary_output_file" ]]; then
        echo "Error: Failed to create temporary file '$temporary_output_file'" >&2
        exit 1
    fi
    
    sudo mv -f "$temporary_output_file" "$output_file"
    
    if [[ ! -f "$output_file" ]] || [[ ! -s "$output_file" ]]; then
        echo "Error: Failed to create file '$output_file'" >&2
        exit 1
    fi
    
    echo "Successfully created: $output_file"
    echo ""
    cat "$output_file"
}

# ==================================================
# INITIALIZE CLEANUP
# ==================================================
trap 'SIGNAL=SIGINT;  exit 130' INT
trap 'SIGNAL=SIGTERM; exit 143' TERM
trap cleanup EXIT

# ==================================================
# PERFORM ACTUAL CHANGES TO THE SYSTEM
# ==================================================
generate_mirror_list --mint-mirror "$MINT_MIRROR" \
                     --ubuntu-mirror "$UBUNTU_MIRROR" \
                     --template "$TEMPLATE_FILE" \
                     --output "$TEMP_SOURCES" \
                     --basecodename "$BASECODENAME" \
                     --codename "$CODENAME" \
                     --replace-security

# HIDE THE OFFICIAL LIST (Move it so APT ignores it entirely)
# This guarantees APT can ONLY talk to LINUX_MIRROR for system packages
sudo mv "$ORIGINAL_SOURCES" "$BACKUP_SOURCES"

# Run system updates using our background-authenticated sudo
echo "--> Synchronizing package indexes from local mirror..."
sudo apt-get update

echo "--> Upgrading system packages..."
sudo apt-get dist-upgrade $DRY_FLAG -y

echo "=================================================="
echo " Done! All user configurations and updates applied. "
echo "=================================================="

[ "$RUN_POST_INSTALL_SCRIPT" = true ] && run_post_install_script

echo "=================================================="
echo " Switch to official local repositories. "
echo "=================================================="

generate_mirror_list --mint-mirror "$MINT_MIRROR_LOCAL" \
                     --ubuntu-mirror "$UBUNTU_MIRROR_LOCAL" \
                     --template "$TEMPLATE_FILE" \
                     --output "$ORIGINAL_SOURCES" \
                     --basecodename "$BASECODENAME" \
                     --codename "$CODENAME"
