#!/bin/bash

set -e

function script_exit() {
	echo "Exiting without committing..."
	exit 1
}

# Trap CTRL+C (SIGINT) and exit the script
trap script_exit SIGINT

CONFIG_PATH="$HOME/.config/git-conventional-commits"
GITMOJI_FILE="$CONFIG_PATH/gitmojis.json"
CONFIG_FILE="$CONFIG_PATH/config.sh"
PROJECT_CONFIG_FILE=".git_cm"
BIN_PATH="$HOME/.local/bin"
SCRIPT_NAME="cm"
SCRIPT_PATH="$BIN_PATH/$SCRIPT_NAME"

## Config defaults in case they are missing from sourced configs.
AUTO_COMMIT=true
CHECK_UNSTAGED=true
CUSTOM_COMMIT_TYPES=()
EMOJI_FORMAT="emoji"
INCLUDE_JIRA_ISSUE_SLUG=true
SCOPES=()
VSCODE_CONVENTIONAL_COMMIT_COMPAT=true
SHOW_EDITOR=false

# Enable for debugging
VERBOSE=${VERBOSE:-false}

#######################################
# Downloads the gitmojis.json file if it doesn't exist in the local
# configuration path. The file contains gitmojis which are emojis representing
# various commit types.
#
# Globals:
#   CONFIG_PATH
#   GITMOJI_FILE
#
# Arguments:
#   None
#
# Outputs:
#   Writes messages to stdout about the download status.
#######################################
function gather_gitmojis() {
	local gitmoji_url="https://raw.githubusercontent.com/carloscuesta/gitmoji/master/packages/gitmojis/src/gitmojis.json"

	# Check if gitmojis.json exists, if not, download it
	if [ ! -f "$GITMOJI_FILE" ]; then
		printf "Downloading gitmojis.json...\n"
		mkdir -p "$CONFIG_PATH"
		wget -N "$gitmoji_url" -O "$GITMOJI_FILE"
	fi
}

#######################################
# Checks if the 'gum' command-line tool is installed and installs it if not.
# 'gum' is used for interactive command-line interfaces.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Outputs:
#   Writes messages to stdout about the installation status of 'gum'.
#   Exits with status code 1 if the installation fails.
#######################################
function check_gum_installed() {
	if ! command -v gum &>/dev/null; then
		printf "Gum is not installed.\n"

		# Detect the operating system
		OS_NAME=$(uname -s)
		case "$OS_NAME" in
		Darwin)
			printf "macOS detected. Installing Gum using Homebrew...\n"
			if ! command -v brew &>/dev/null; then
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
				ubuntu | debian)
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

		if ! command -v gum &>/dev/null; then
			printf "Failed to install Gum. Please install it manually.\n"
			return 1
		fi
	fi
}

#######################################
# Checks if the 'jq' command-line tool is installed and installs it if not.
# 'jq' is used for processing JSON files.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Outputs:
#   Writes messages to stdout about the installation status of 'jq'.
#   Exits with status code 1 if the installation fails.
#######################################
function check_jq_installed() {
	if ! command -v jq &>/dev/null; then
		printf "jq is not installed.\n"

		# Detect the operating system
		OS_NAME=$(uname -s)
		case "$OS_NAME" in
		Darwin)
			printf "macOS detected. Installing jq using Homebrew...\n"
			if ! command -v brew &>/dev/null; then
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
				ubuntu | debian)
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

		if ! command -v jq &>/dev/null; then
			printf "Failed to install jq. Please install it manually.\n"
			return 1
		fi
	fi
}

#######################################
# Validates if '~/.local/bin' is in the user's PATH.
# Provides instructions to add it if not present.
#
# Globals:
#   PATH
#
# Arguments:
#   None
#
# Outputs:
#   Writes instructions to stdout on how to add '~/.local/bin' to PATH.
#######################################
function validate_local_bin_in_path() {
	if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
		printf "It looks like ~/.local/bin is not in your PATH.\n"
		printf "To add ~/.local/bin to your PATH, you can add the following line to your ~/.bashrc, ~/.zshrc, or equivalent shell configuration file:\n"
		# shellcheck disable=SC2016
		printf 'export PATH="$HOME/.local/bin:$PATH"\n'
		printf "After adding the line, restart your terminal or source the configuration file to update your PATH.\n"
	fi
}

#######################################
# Generates a default 'config.sh' file with default configuration values
# if it doesn't exist in the local configuration path.
#
# Globals:
#   CONFIG_PATH
#   CONFIG_FILE
#
# Arguments:
#   None
#
# Outputs:
#   Writes messages to stdout about the creation status of the default
#   'config.sh'.
#######################################
function generate_default_config() {
	local config_file_path="$CONFIG_PATH/config.sh"

	if [ ! -f "$config_file_path" ]; then
		printf "Generating default config.sh file...\n"

		# Create the config directory if it doesn't exist
		mkdir -p "$CONFIG_PATH"

		# Write default configuration content to config.sh
		cat >"$config_file_path" <<-'EOF'
			#!/bin/bash
			# shellcheck disable=SC2034

			# Default configuration for Git Commit Message Wizard

			# Emoji format: "emoji" for actual emoji, "code" for emoji code
			#
			# NOTE: "emoji" takes less space on the commit line, but is not supported by all
			# git clients. For most modern tooling, "emoji" works well.
			EMOJI_FORMAT="emoji"

			# Additional Conventional Commit Types
			# Example: CUSTOM_COMMIT_TYPES=("metadata")
			CUSTOM_COMMIT_TYPES=()

			# Auto-append a git-trailer for your Jira issues?
			INCLUDE_JIRA_ISSUE_SLUG=true

			# Predefined scopes (add your scopes here)
			# Example: SCOPES=("frontend" "backend" "database")
			SCOPES=()

			# Enable compatibility with VSCode Conventional Commit Extension
			VSCODE_CONVENTIONAL_COMMIT_COMPAT=true

			# Check for unstaged files and offer to add them to the commit.
			CHECK_UNSTAGED=true

			# Show the commit message in the editor before committing.
			SHOW_EDITOR=false

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

#######################################
# Sources the global 'config.sh' and project-specific '.git_cm' configuration
# files if they exist.
# Also reads the '.vscode/settings.json' file for additional scopes.
#
# Globals:
#   CONFIG_FILE
#   PROJECT_CONFIG_FILE
#
# Arguments:
#   None
#
# Outputs:
#   Writes messages to stdout about the sourcing status of configuration files.
#######################################
function source_config() {
	if [ -f "$CONFIG_FILE" ]; then
		# shellcheck source=/dev/null
		source "$CONFIG_FILE"
	fi

	# Get any VSCode Conventional Commit Extension project settings
	project_root_dir=$(git rev-parse --show-toplevel) # Get the root directory of the Git project

	# Define the path for the project-specific config
	local project_specific_config
	project_specific_config="$project_root_dir/$PROJECT_CONFIG_FILE"

	# Source project-specific config if it exists
	if [ -f "$project_specific_config" ]; then
		# shellcheck source=/dev/null
		source "$project_specific_config"
	fi

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

#######################################
# Checks and installs dependencies, validates the local bin path,
# generates the default config, and sources the configurations.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Outputs:
#   Writes messages to stdout about the status of dependency checks and
#   installations.
#######################################
function check_dependencies() {
	gather_gitmojis
	check_gum_installed
	check_jq_installed
	validate_local_bin_in_path
	generate_default_config
	source_config
}

#######################################
# Installs the script by copying it to the '~/.local/bin' directory
# and setting up a git alias 'cm'.
#
# Globals:
#   BIN_PATH
#   SCRIPT_NAME
#   SCRIPT_PATH
#
# Arguments:
#   None
#
# Outputs:
#   Writes messages to stdout about the installation status of the script.
#######################################
function install_script() {
	mkdir -p "$BIN_PATH"
	cp "$0" "$SCRIPT_PATH"
	chmod +x "$SCRIPT_PATH"

	# Check if git alias already exists
	if git config --global --get alias.cm &>/dev/null; then
		printf "Git alias 'cm' already exists. Skipping alias setup.\n"
	else
		git config --global alias.cm "!$SCRIPT_PATH"
		printf "Git alias 'cm' has been set up.\n"
	fi

	printf "Installation complete. Use 'git cm' to start your commits.\n"
}

#######################################
# Checks for uncommitted changes in the git repository and offers to stage them.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Outputs:
#   Writes the status of uncommitted changes and staging confirmation to stdout.
#######################################
function check_and_stage_changes() {
	# Check for uncommitted changes
	if ! git diff --quiet; then
		echo "Uncommitted changes detected."
		git status --short

		# Ask the user if they want to add all changes to the commit
		if gum confirm "Would you like to add all changes to the commit?"; then
			# Add all changes
			git add -A
			echo "All changes added to the commit."
		else
			echo "Proceeding without adding changes."
		fi
	else
		if [ "$VERBOSE" = "true" ]; then
			echo "No uncommitted changes detected."
		fi
	fi
}

#######################################
# Allows the user to select a gitmoji for the commit message or choose "None"
# for no gitmoji. Gitmojis are emojis representing various commit types.
#
# Globals:
#   GITMOJI_FILE
#   EMOJI_FORMAT
#
# Arguments:
#   None
#
# Outputs:
#   Sets the selected gitmoji to the global variable GITMOJI_CODE or sets it
#   to an empty value if "None" is selected.
#######################################
function select_gitmoji() {
	local gitmoji_list
	local none_option="None - No gitmoji"

	if [ "$EMOJI_FORMAT" = "code" ]; then
		gitmoji_list=$(jq -r '.gitmojis[] | .code + " - " + .description' "$GITMOJI_FILE")
	else
		gitmoji_list=$(jq -r '.gitmojis[] | .emoji + " - " + .description' "$GITMOJI_FILE")
	fi

	# Add the "None" option to the list
	gitmoji_list="$none_option"$'\n'"$gitmoji_list"

	GITMOJI_CODE=$(printf "%s\n" "$gitmoji_list" | gum filter --placeholder "Filter gitmojis or select 'None' for no gitmoji")

	# Check if the "None" option was selected
	if [[ "$GITMOJI_CODE" == "$none_option" ]]; then
		GITMOJI_CODE="" # Set GITMOJI_CODE to an empty value
	else
		GITMOJI_CODE=$(echo "$GITMOJI_CODE" | awk '{print $1}') # Extract only the emoji or code
	fi
}

#######################################
# Includes a JIRA issue slug in the commit message if the branch name contains a
# JIRA issue key.
#
# Globals:
#   INCLUDE_JIRA_ISSUE_SLUG
#
# Arguments:
#   None
#
# Outputs:
#   Sets the JIRA issue slug to the global variable JIRA_ISSUE_TRAILER if
#   confirmed by the user.
#######################################
function include_jira_issue_slug() {
	if [ "$INCLUDE_JIRA_ISSUE_SLUG" = true ]; then
		local branch_name
		branch_name=$(git branch --show-current)

		# Regex to match JIRA issue slug (e.g., ABC-1234)
		local jira_issue_regex='[A-Z]+-[0-9]+'
		local jira_issue_slug
		jira_issue_slug=$(echo "$branch_name" | grep -oE "$jira_issue_regex" | head -n 1)

		if [ "$VERBOSE" = "true" ]; then
			echo "jira_issue_slug: $jira_issue_slug"
			echo "jira_issue_regex: $jira_issue_regex"
		fi

		if [ -n "$jira_issue_slug" ]; then
			if gum confirm "Would you like to add 'jira-issue: [$jira_issue_slug]' to your commit message?"; then
				JIRA_ISSUE_TRAILER="jira-issue: [$jira_issue_slug]"
			fi
		fi
	fi
}

#######################################
# Allows the user to select the type of commit from a list of standard and
# custom commit types.
#
# Globals:
#   CUSTOM_COMMIT_TYPES
#
# Arguments:
#   None
#
# Outputs:
#   Sets the selected commit type to the global variable COMMIT_TYPE.
#######################################
function select_commit_type() {
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
		"BREAKING CHANGE: A change that will break the current functionality"
	)

	# Extend commit types with custom types from config
	if [ -n "${CUSTOM_COMMIT_TYPES+x}" ]; then
		COMMIT_TYPES+=("${CUSTOM_COMMIT_TYPES[@]}")
	fi

	COMMIT_TYPE=$(printf "%s\n" "${COMMIT_TYPES[@]}" | gum filter --placeholder "Filter types")
	SELECTED_TYPE=$(echo "$COMMIT_TYPE" | awk -F": " '{print $1}') # Extract only the commit type

	# Check if the selected type is a breaking change
	if [ "$SELECTED_TYPE" = "BREAKING CHANGE" ]; then
		# Remove the "BREAKING CHANGE" option for the second selection
		COMMIT_TYPES=("${COMMIT_TYPES[@]/"BREAKING CHANGE: A change that will break the current functionality"/}")
		COMMIT_TYPE=$(printf "%s\n" "${COMMIT_TYPES[@]}" | gum filter --placeholder "Select the type of BREAKING CHANGE...")
		COMMIT_TYPE=$(echo "$COMMIT_TYPE" | awk -F": " '{print $1}') # Extract only the commit type
		COMMIT_TYPE="$COMMIT_TYPE!"                                  # Mark as breaking change
	else
		COMMIT_TYPE="$SELECTED_TYPE"
	fi
}

#######################################
# Allows the user to select or define the scope of the commit.
#
# Globals:
#   SCOPES
#   VSCODE_CONVENTIONAL_COMMIT_COMPAT
#
# Arguments:
#   None
#
# Outputs:
#   Sets the selected or defined commit scope to the global variable
#   COMMIT_SCOPE.
#######################################
function select_commit_scope() {
	local special_scopes=("New Scope (add new project scope)" "New Scope (only use once)")
	local combined_scopes=("None" "${SCOPES[@]}" "${special_scopes[@]}")

	COMMIT_SCOPE=$(printf "%s\n" "${combined_scopes[@]}" | gum choose --limit=1)

	case "$COMMIT_SCOPE" in
	"None")
		COMMIT_SCOPE=""
		;;
	"New Scope (add new project scope)")
		COMMIT_SCOPE=$(gum input --placeholder "Enter new scope")
		if [ "$VSCODE_CONVENTIONAL_COMMIT_COMPAT" = true ]; then
			add_scope_to_settings_json "$COMMIT_SCOPE"
		else
			add_scope_to_local_config "$COMMIT_SCOPE"
		fi
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

#######################################
# Adds a new scope to the '.vscode/settings.json' file.
# This is compatible with the VSCode Conventional Commit Extension.
#
# Globals:
#   None
#
# Arguments:
#   new_scope - The new scope to be added.
#
# Outputs:
#   Updates the '.vscode/settings.json' file with the new scope.
#######################################
function add_scope_to_settings_json() {
	local new_scope=$1
	local settings_json="$project_root_dir/.vscode/settings.json"

	if [ -f "$settings_json" ]; then
		# Add new scope to the settings.json file
		jq --arg new_scope "$new_scope" '.["conventionalCommits.scopes"] += [$new_scope]' "$settings_json" >tmp.json && mv tmp.json "$settings_json"
	else
		# Create settings.json with the new scope
		mkdir -p "$project_root_dir/.vscode"
		echo "{\"conventionalCommits.scopes\": [\"$new_scope\"]}" >"$settings_json"
	fi
}

#######################################
# Adds a new scope to the project-specific '.git_cm' configuration file.
#
# Globals:
#   None
#
# Arguments:
#   new_scope - The new scope to be added.
#
# Outputs:
#   Updates the project-specific '.git_cm' configuration file with the new
#   scope.
#######################################
function add_scope_to_local_config() {
	local new_scope=$1
	local project_specific_config="$project_root_dir/$PROJECT_CONFIG_FILE"

	if [ -f "$project_specific_config" ]; then
		# Check if SCOPES array exists in the file and add the new scope
		if grep -q "SCOPES=" "$project_specific_config"; then
			# Append the new scope to the existing SCOPES array
			awk -v new_scope="\"$new_scope\"" '/^SCOPES=/ {
                sub(/\)$/, "");
                print $0 " " new_scope ")";
                next;
            }
            {print}' "$project_specific_config" >tmp_config && mv tmp_config "$project_specific_config"
		else
			# Add a new SCOPES array with the new scope
			echo "SCOPES=(\"$new_scope\")" >>"$project_specific_config"
		fi
	else
		# Create the project-specific config file with the new SCOPES array
		echo "#!/bin/bash" >"$project_specific_config"
		# shellcheck disable=SC2129
		echo "# shellcheck disable=SC2034" >>"$project_specific_config"
		echo "# Project-specific configuration for Git Conventional Commit Wizard" >>"$project_specific_config"
		echo "SCOPES=(\"$new_scope\")" >>"$project_specific_config"
	fi
}

#######################################
# Prompts the user to enter the commit message, constructs the commit message
# by combining the selected type, scope, gitmoji, and description,
# and offers to add a detailed commit body.
#
# Globals:
#   COMMIT_TYPE
#   COMMIT_SCOPE
#   GITMOJI_CODE
#   JIRA_ISSUE_TRAILER
#
# Arguments:
#   None
#
# Outputs:
#   Sets the constructed commit message to the global variables COMMIT_MESSAGE
#   and COMMIT_BODY.
#######################################
function create_commit_message() {
	COMMIT_DESC=$(gum input --placeholder "Enter short description (50 chars max)")

	# shellcheck disable=SC2128
	if [ -n "$COMMIT_SCOPE" ]; then
		COMMIT_SCOPE="($COMMIT_SCOPE)"
	fi

	# Start constructing the commit message
	COMMIT_MESSAGE="$COMMIT_TYPE$COMMIT_SCOPE: $GITMOJI_CODE $COMMIT_DESC"

	# Initialize an empty variable for the commit body
	COMMIT_BODY=""

	# Prompt for additional commit body
	if gum confirm "Add a more detailed commit body?"; then
		COMMIT_BODY=$(gum write --placeholder "Enter additional commit message (CTRL+D to finish)" | fold -s -w 72)
	fi

	# Append the commit body if provided
	if [ -n "$COMMIT_BODY" ]; then
		COMMIT_MESSAGE="$COMMIT_MESSAGE"$'\n\n'"$COMMIT_BODY"
	fi

	# Include JIRA issue slug if present in branch name
	include_jira_issue_slug

	# Append JIRA issue trailer if confirmed by the user
	if [ -n "$JIRA_ISSUE_TRAILER" ]; then
		COMMIT_MESSAGE="$COMMIT_MESSAGE"$'\n\n'"$JIRA_ISSUE_TRAILER"
	fi

	# Check if it's a breaking change and prompt for details to be added last
	if [[ "$COMMIT_TYPE" == *'!' ]]; then
		BREAKING_CHANGE_DETAILS=$(gum input --placeholder "Enter BREAKING CHANGE details")
		if [ -n "$BREAKING_CHANGE_DETAILS" ]; then
			# Append BREAKING CHANGE footer as the last part of the commit message
			COMMIT_MESSAGE="$COMMIT_MESSAGE"$'\n\n'"BREAKING CHANGE: $BREAKING_CHANGE_DETAILS"
		fi
	fi

	if [ "$VERBOSE" = "true" ]; then
		printf "COMMIT_MESSAGE: %s\n" "$COMMIT_MESSAGE"
	fi
}

#######################################
# Performs the git commit with the constructed commit message and body.
# If SHOW_EDITOR is true, opens the commit message in the default editor before committing.
#
# Globals:
#   AUTO_COMMIT
#   COMMIT_MESSAGE
#   COMMIT_BODY
#   SHOW_EDITOR
#
# Arguments:
#   None
#
# Outputs:
#   Executes the git commit command with the constructed message and body.
#   Writes messages to stdout about the commit status.
#######################################
function perform_git_commit() {
	if [ "$AUTO_COMMIT" = true ] || gum confirm "Commit your message?"; then
		local tmpfile
		tmpfile=$(mktemp)
		trap 'rm -f $tmpfile' EXIT

		echo "$COMMIT_MESSAGE" >"$tmpfile"
		if [ -n "$COMMIT_BODY" ] && [[ "$COMMIT_MESSAGE" != *"$COMMIT_BODY"* ]]; then
			echo "" >>"$tmpfile"
			echo "$COMMIT_BODY" >>"$tmpfile"
		fi

		# Open the commit message in the editor if SHOW_EDITOR is true
		if [ "$SHOW_EDITOR" = true ]; then
			${EDITOR:-vi} "$tmpfile"
		fi

		if git commit -F "$tmpfile"; then
			echo "Commit successful."
		else
			echo "Commit failed."
		fi
	else
		echo "Commit aborted."
	fi
}

#######################################
# The main function that orchestrates the script execution.
# It checks for the 'install' argument to either install the script
# or proceed with the commit message creation and git commit process.
#
# Globals:
#   CHECK_UNSTAGED
#
# Arguments:
#   $1 - The first command-line argument passed to the script.
#
# Outputs:
#   Depending on the argument, it either installs the script or initiates the
#   wizard for the git commit process.
#######################################
function main() {
	if [[ "$1" == "install" ]]; then
		check_dependencies
		install_script
	else
		check_dependencies
		if [ "$CHECK_UNSTAGED" = "true" ]; then
			check_and_stage_changes
		fi
		select_commit_type
		select_commit_scope
		select_gitmoji
		create_commit_message
		perform_git_commit
	fi
}

main "$@"
