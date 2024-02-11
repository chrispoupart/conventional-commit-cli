#!/bin/bash

CONFIG_PATH="$HOME/.config/git-conventional-commits"
GITMOJI_FILE="$CONFIG_PATH/gitmojis.json"
CONFIG_FILE="$CONFIG_PATH/config.sh"
BIN_PATH="$HOME/.local/bin"
SCRIPT_NAME="cm"
SCRIPT_PATH="$BIN_PATH/$SCRIPT_NAME"
AUTO_COMMIT=true

# Enable for debugging
VERBOSE=${VERBOSE:-false}

function gather_gitmojis() {
  local gitmoji_url="https://raw.githubusercontent.com/carloscuesta/gitmoji/master/packages/gitmojis/src/gitmojis.json"

  # Check if gitmojis.json exists, if not, download it
  if [ ! -f "$GITMOJI_FILE" ]; then
      printf "Downloading gitmojis.json...\n"
      mkdir -p "$CONFIG_PATH"
      wget -N "$gitmoji_url" -O "$GITMOJI_FILE"
  fi
}

# Function to check if Gum is installed
function check_gum_installed() {
    if ! command -v gum &> /dev/null; then
        printf "Gum is not installed.\n"

        # Detect the operating system
        OS_NAME=$(uname -s)
        case "$OS_NAME" in
            Darwin)
                printf "macOS detected. Installing Gum using Homebrew...\n"
                if ! command -v brew &> /dev/null; then
                  printf "Please install Homebrew and try again.\n"
                  return 1
                else
                  brew install charmbracelet/homebrew-tap/gum
                fi
                ;;
            Linux)
                # Check for specific Linux distributions
                if [ -f /etc/os-release ]; then
                    # shellcheck source=/dev/null
                    . /etc/os-release
                    case "$ID" in
                        ubuntu|debian)
                            printf "Ubuntu/Debian detected. Installing Gum...\n"
                            sudo mkdir -p /etc/apt/keyrings
                            curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
                            printf "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *\n" | sudo tee /etc/apt/sources.list.d/charm.list
                            sudo apt update && sudo apt install gum
                            ;;
                        fedora)
                            printf "Fedora detected. Installing Gum using DNF...\n"
                            local yum_repo
                            yum_repo=(
                                "[charm]"
                                "name=Charm"
                                "baseurl=https://repo.charm.sh/yum/"
                                "enabled=1"
                                "gpgcheck=1"
                                "gpgkey=https://repo.charm.sh/yum/gpg.key"
                            )
                            printf '%s\n' "${yum_repo[@]}" | sudo tee /etc/yum.repos.d/charm.repo
                            sudo yum -y install gum
                            ;;
                        *)
                            printf "Unsupported Linux distribution. Please visit the Gum GitHub project site for installation instructions.\n"
                            printf "https://github.com/charmbracelet/gum\n"
                            return 1
                            ;;
                    esac
                else
                    printf "Unable to detect Linux distribution. Please visit the Gum GitHub project site for installation instructions.\n"
                    printf "https://github.com/charmbracelet/gum\n"
                    return 1
                fi
                ;;
            *)
                printf "Unsupported operating system. Please visit the Gum GitHub project site for installation instructions.\n"
                printf "https://github.com/charmbracelet/gum\n"
                return 1
                ;;
        esac

        if ! command -v gum &> /dev/null; then
            printf "Failed to install Gum. Please install it manually.\n"
            return 1
        fi
    fi
}

function check_jq_installed() {
    if ! command -v jq &> /dev/null; then
        printf "jq is not installed.\n"

        # Detect the operating system
        OS_NAME=$(uname -s)
        case "$OS_NAME" in
            Darwin)
                printf "macOS detected. Installing jq using Homebrew...\n"
                if ! command -v brew &> /dev/null; then
                  printf "Please install Homebrew and try again.\n"
                  return 1
                else
                  brew install jq
                fi
                ;;
            Linux)
                # Check for specific Linux distributions
                if [ -f /etc/os-release ]; then
                    # shellcheck source=/dev/null
                    . /etc/os-release
                    case "$ID" in
                        ubuntu|debian)
                            printf "Ubuntu/Debian detected. Installing jq...\n"
                            sudo apt update && sudo apt install jq
                            ;;
                        fedora)
                            printf "Fedora detected. Installing jq using DNF...\n"
                            sudo dnf -y install jq
                            ;;
                        *)
                            printf "Unsupported Linux distribution. Please install jq manually.\n"
                            return 1
                            ;;
                    esac
                else
                    printf "Unable to detect Linux distribution. Please install jq manually.\n"
                    return 1
                fi
                ;;
            *)
                printf "Unsupported operating system. Please install jq manually.\n"
                return 1
                ;;
        esac

        if ! command -v jq &> /dev/null; then
            printf "Failed to install jq. Please install it manually.\n"
            return 1
        fi
    fi
}

# Function to check if ~/.local/bin is in PATH
function validate_local_bin_in_path() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        printf "It looks like ~/.local/bin is not in your PATH.\n"
        printf "To add ~/.local/bin to your PATH, you can add the following line to your ~/.bashrc, ~/.zshrc, or equivalent shell configuration file:\n"
        # shellcheck disable=SC2016
        printf 'export PATH="$HOME/.local/bin:$PATH"\n'
        printf "After adding the line, restart your terminal or source the configuration file to update your PATH.\n"
    fi
}

# Function to generate default config.sh file
generate_default_config() {
    local config_file_path="$CONFIG_PATH/config.sh"

    if [ ! -f "$config_file_path" ]; then
        printf "Generating default config.sh file...\n"

        # Create the config directory if it doesn't exist
        mkdir -p "$CONFIG_PATH"

        # Write default configuration content to config.sh
        cat > "$config_file_path" <<- 'EOF'
# Default configuration for Git Commit Message Wizard

# Emoji format: "emoji" for actual emoji, "code" for emoji code
#
# "emoji" takes less space on the commit line, but is not supported by all git
# clients. For most modern tooling, "emoji" works well.
EMOJI_FORMAT="emoji"

# Additional Conventional Commit Types
# Example: CUSTOM_COMMIT_TYPES=("metadata")
CUSTOM_COMMIT_TYPES=()

# Predefined scopes (add your scopes here)
# Example: SCOPES=("frontend" "backend" "database")
SCOPES=()

# Automatically commit the message without a prompt?
AUTO_COMMIT=true
EOF
        printf "Default config.sh file created at %s\n" "$config_file_path"
    else
        if [ "$VERBOSE" = "true" ]; then
            printf "config.sh already exists at %s\n" "$config_file_path\n"
        fi
    fi
}

# Function to source configuration(s)
function source_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi

    # Get any VSCode Conventional Commit Extension project settings
    project_root_dir=$(git rev-parse --show-toplevel)  # Get the root directory of the Git project
    local settings_json="$project_root_dir/.vscode/settings.json"

    if [ -f "$settings_json" ]; then
        # Extract scopes from settings.json and append them to the SCOPES array
        local project_scopes
        project_scopes=$(jq -r '.["conventionalCommits.scopes"][]' "$settings_json")
        if [ -n "$project_scopes" ]; then
            SCOPES+=("$project_scopes")
            # Make sure the SCOPES are unique
            local sorted_unique_scopes=("$(printf '%s\n' "${SCOPES[@]}" | sort -u)")
            SCOPES=("${sorted_unique_scopes[@]}")
            if [ "$VERBOSE" = "true" ]; then
                printf "SCOPES: %s\n" "${SCOPES[*]}"
            fi
        fi
    fi
}

# Check dependencies
function check_dependencies() {
    gather_gitmojis
    check_gum_installed
    check_jq_installed
    validate_local_bin_in_path
    generate_default_config
    source_config
}

# Function to install the script
install_script() {
    mkdir -p "$BIN_PATH"
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"

    # Check if git alias already exists
    if git config --global --get alias.cm &> /dev/null; then
        printf "Git alias 'cm' already exists. Skipping alias setup.\n"
    else
        git config --global alias.cm "!$SCRIPT_PATH"
        printf "Git alias 'cm' has been set up.\n"
    fi

    printf "Installation complete. Use 'git cm' to start your commits.\n"
}

# Function to select gitmoji
function select_gitmoji() {
    local gitmoji_list
    if [ "$EMOJI_FORMAT" = "code" ]; then
        gitmoji_list=$(jq -r '.gitmojis[] | .code + " - " + .description' "$GITMOJI_FILE")
    else
        gitmoji_list=$(jq -r '.gitmojis[] | .emoji + " - " + .description' "$GITMOJI_FILE")
    fi

    GITMOJI_CODE=$(printf "%s\n" "$gitmoji_list" | gum filter --placeholder "Filter gitmojis")
    GITMOJI_CODE=$(echo "$GITMOJI_CODE" | awk '{print $1}') # Extract only the emoji or code
}

# Function to select commit type
select_commit_type() {
    COMMIT_TYPES=(
      "feat: A new feature"
      "fix: A bug fix"
      "docs: Documentation only changes"
      "style: Changes that do not affect the meaning of the code"
      "refactor: A code change that neither fixes a bug nor adds a feature"
      "perf: A code change that improves performance"
      "test: Adding missing tests or correcting existing tests"
      "build: Changes that affect the build system or external dependencies"
      "ci: Changes to our CI configuration files and scripts"
      "chore: Other changes that don't modify src or test files"
      "revert: Reverts a previous commit"
    )

    # Extend commit types with custom types from config
    if [ -n "${CUSTOM_COMMIT_TYPES+x}" ]; then
        COMMIT_TYPES+=("${CUSTOM_COMMIT_TYPES[@]}")
    fi

    COMMIT_TYPE=$(printf "%s\n" "${COMMIT_TYPES[@]}" | gum filter --placeholder "Filter types")
    COMMIT_TYPE=$(echo "$COMMIT_TYPE" | awk -F": " '{print $1}') # Extract only the commit type
}

# Function to select commit scope
select_commit_scope() {
    local special_scopes=("New Scope (add new project scope)" "New Scope (only use once)")
    local combined_scopes=("None" "${SCOPES[@]}" "${special_scopes[@]}")

    COMMIT_SCOPE=$(printf "%s\n" "${combined_scopes[@]}" | gum choose --limit=1)

    case "$COMMIT_SCOPE" in
        "None")
            COMMIT_SCOPE=""
            ;;
        "New Scope (add new project scope)")
            COMMIT_SCOPE=$(gum input --placeholder "Enter new scope")
            add_scope_to_settings_json "$COMMIT_SCOPE"
            ;;
        "New Scope (only use once)")
            COMMIT_SCOPE=$(gum input --placeholder "Enter new scope")
            ;;
        *)
            # Existing scope selected, no action needed
            ;;
    esac

    if [ -n "$COMMIT_SCOPE" ]; then
        COMMIT_SCOPE=("$COMMIT_SCOPE")
    fi
}

# Function to add a new scope to .vscode/settings.json.
# This aims to be compatible with the VSCode Conventional Commit Extension
add_scope_to_settings_json() {
    local new_scope=$1
    local settings_json="$project_root_dir/.vscode/settings.json"

    if [ -f "$settings_json" ]; then
        # Add new scope to the settings.json file
        jq --arg new_scope "$new_scope" '.["conventionalCommits.scopes"] += [$new_scope]' "$settings_json" > tmp.json && mv tmp.json "$settings_json"
    else
        # Create settings.json with the new scope
        mkdir -p "$project_root_dir/.vscode"
        echo "{\"conventionalCommits.scopes\": [\"$new_scope\"]}" > "$settings_json"
    fi
}

# Function to create commit message
create_commit_message() {
    COMMIT_DESC=$(gum input --placeholder "Enter short description (50 chars max)")

    # shellcheck disable=SC2128
    if [ -n "$COMMIT_SCOPE" ]; then
        COMMIT_SCOPE="($COMMIT_SCOPE)"
    fi

    COMMIT_MESSAGE="$COMMIT_TYPE$COMMIT_SCOPE: $GITMOJI_CODE $COMMIT_DESC"

    if gum confirm "Add a more detailed commit body?"; then
        COMMIT_BODY=$(gum write --placeholder "Enter additional commit message (CTRL+D to finish)" | fold -s -w 72)
    fi
    if [ "$VERBOSE" = "true" ]; then
        printf "COMMIT_MESSAGE: %s\n" "$COMMIT_MESSAGE"
        printf "COMMIT_BODY: %s\n" "$COMMIT_BODY"
    fi
}

perform_git_commit() {
    if [ $AUTO_COMMIT = true ] || gum confirm "Commit your message?"; then
        if [ -n "$COMMIT_MESSAGE" ] && [ -n "$COMMIT_BODY" ]; then
            git commit -m "$COMMIT_MESSAGE" -m "$COMMIT_BODY"
        elif [ -n "$COMMIT_MESSAGE" ]; then
            git commit -m "$COMMIT_MESSAGE"
        else
            printf "Commit message is empty. Commit aborted.\n"
        fi
    else
        printf "Commit aborted.\n"
    fi
}

# Main script execution
function main() {
    if [[ "$1" == "install" ]]; then
        check_dependencies
        install_script
    else
        check_dependencies
        select_commit_type
        select_commit_scope
        select_gitmoji
        create_commit_message
        perform_git_commit
    fi
}

main "$@"
