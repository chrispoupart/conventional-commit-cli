#!/bin/bash

CONFIG_PATH="$HOME/.config/git-conventional-commits"
GITMOJI_FILE="$CONFIG_PATH/gitmojis.json"
CONFIG_FILE="$CONFIG_PATH/config.sh"
BIN_PATH="$HOME/.local/bin"
SCRIPT_NAME="cm"
SCRIPT_PATH="$BIN_PATH/$SCRIPT_NAME"

function gather_gitmojis() {
  local gitmoji_url="https://raw.githubusercontent.com/carloscuesta/gitmoji/master/packages/gitmojis/src/gitmojis.json"

  # Check if gitmojis.json exists, if not, download it
  if [ ! -f "$GITMOJI_FILE" ]; then
      echo "Downloading gitmojis.json..."
      mkdir -p "$CONFIG_PATH"
      curl -sL "$gitmoji_url" -o "$GITMOJI_FILE"
fi
}

# Function to check if Gum is installed
function check_gum_installed() {
    if ! command -v gum &> /dev/null; then
        echo "Gum is not installed."

        # Detect the operating system
        OS_NAME=$(uname -s)
        case "$OS_NAME" in
            Darwin)
                echo "macOS detected. Installing Gum using Homebrew..."
                if ! command -v brew &> /dev/null; then
                  echo "Please install Homebrew and try again."
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
                            echo "Ubuntu/Debian detected. Installing Gum..."
                            sudo mkdir -p /etc/apt/keyrings
                            curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
                            echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
                            sudo apt update && sudo apt install gum
                            ;;
                        fedora)
                            echo "Fedora detected. Installing Gum using DNF..."
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
                            echo "Unsupported Linux distribution. Please visit the Gum GitHub project site for installation instructions."
                            echo "https://github.com/charmbracelet/gum"
                            exit 1
                            ;;
                    esac
                else
                    echo "Unable to detect Linux distribution. Please visit the Gum GitHub project site for installation instructions."
                    echo "https://github.com/charmbracelet/gum"
                    exit 1
                fi
                ;;
            *)
                echo "Unsupported operating system. Please visit the Gum GitHub project site for installation instructions."
                echo "https://github.com/charmbracelet/gum"
                exit 1
                ;;
        esac

        if ! command -v gum &> /dev/null; then
            echo "Failed to install Gum. Please install it manually."
            exit 1
        fi
    fi
}

function check_jq_installed() {
    if ! command -v jq &> /dev/null; then
        echo "jq is not installed."

        # Detect the operating system
        OS_NAME=$(uname -s)
        case "$OS_NAME" in
            Darwin)
                echo "macOS detected. Installing jq using Homebrew..."
                if ! command -v brew &> /dev/null; then
                  echo "Please install Homebrew and try again."
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
                            echo "Ubuntu/Debian detected. Installing jq..."
                            sudo apt update && sudo apt install jq
                            ;;
                        fedora)
                            echo "Fedora detected. Installing jq using DNF..."
                            sudo dnf install jq
                            ;;
                        *)
                            echo "Unsupported Linux distribution. Please install jq manually."
                            exit 1
                            ;;
                    esac
                else
                    echo "Unable to detect Linux distribution. Please install jq manually."
                    exit 1
                fi
                ;;
            *)
                echo "Unsupported operating system. Please install jq manually."
                exit 1
                ;;
        esac

        if ! command -v jq &> /dev/null; then
            echo "Failed to install jq. Please install it manually."
            exit 1
        fi
    fi
}

# Function to check if ~/.local/bin is in PATH
function validate_local_bin_in_path() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo "It looks like ~/.local/bin is not in your PATH."
        echo "To add ~/.local/bin to your PATH, you can add the following line to your ~/.bashrc, ~/.zshrc, or equivalent shell configuration file:"
        # shellcheck disable=SC2016
        echo 'export PATH="$HOME/.local/bin:$PATH"'
        echo "After adding the line, restart your terminal or source the configuration file to update your PATH."
    fi
}

# Function to source project configuration
function source_project_config() {
  if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  fi
}

# Check dependencies
function check_dependencies() {
  gather_gitmojis
  check_gum_installed
  check_jq_installed
  validate_local_bin_in_path
}

# Function to select gitmoji
function select_gitmoji() {
     if [ "$EMOJI_FORMAT" = "code" ]; then
        GITMOJI_CODE=$(jq -r '.gitmojis[] | .code + " - " + .description' "$GITMOJI_FILE" | gum choose --limit=1)
        GITMOJI_CODE=$(echo "$GITMOJI_CODE" | awk '{print $1}') # Extract only the emoji code
    else
        GITMOJI_CODE=$(jq -r '.gitmojis[] | .emoji + " - " + .description' "$GITMOJI_FILE" | gum choose --limit=1)
        GITMOJI_CODE=$(echo "$GITMOJI_CODE" | awk '{print $1}') # Extract only the emoji
    fi
}

# Function to install the script
install_script() {
    mkdir -p "$BIN_PATH"
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"

    # Check if git alias already exists
    if git config --global --get alias.cm &> /dev/null; then
        echo "Git alias 'cm' already exists. Skipping alias setup."
    else
        git config --global alias.cm "!$SCRIPT_PATH"
        echo "Git alias 'cm' has been set up."
    fi

    echo "Installation complete. Use 'git cm' to start your commits."
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

    COMMIT_TYPE=$(printf "%s\n" "${COMMIT_TYPES[@]}" | gum choose --limit=1)
    COMMIT_TYPE=$(echo "$COMMIT_TYPE" | awk -F": " '{print $1}') # Extract only the commit type
}

# Function to create commit message
create_commit_message() {
    COMMIT_SCOPE=$(gum input --placeholder "Enter scope (optional)")
    COMMIT_DESC=$(gum input --placeholder "Enter short description")

    if [ -n "$COMMIT_SCOPE" ]; then
        COMMIT_SCOPE="($COMMIT_SCOPE)"
    fi

    COMMIT_MESSAGE="$COMMIT_TYPE$COMMIT_SCOPE: $GITMOJI_CODE $COMMIT_DESC"

    if gum confirm "Add a more detailed commit body?"; then
        COMMIT_BODY=$(gum write --placeholder "Enter additional commit message (CTRL+D to finish)" | fold -s -w 72)
    fi
}

perform_git_commit() {
    if [ -n "$COMMIT_MESSAGE" ] && [ -n "$COMMIT_BODY" ]; then
        git commit -m "$COMMIT_MESSAGE" -m "$COMMIT_BODY"
    elif [ -n "$COMMIT_MESSAGE" ]; then
        git commit -m "$COMMIT_MESSAGE"
    else
        echo "Commit message is empty. Commit aborted."
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
        select_gitmoji
        create_commit_message
        perform_git_commit
    fi
}

main "$@"
