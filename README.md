# Git Conventional Commit CLI Wizard

This script provides an interactive command-line interface for creating
structured and Conventional Commit messages. It integrates with Git, allowing
users to select commit types, scopes, and emojis (or emoji codes) for their
commit messages.

## Features

- Interactive selection of commit types and emojis
- Support for long commit messages with an optional body
- Customizable through a configuration file
- Easy installation with Git alias integration

## Installation

1. **Clone the Repository**:
2. **Run the Installation Command**:

   ```bash
   ./conventional-commits.sh install
   ```

   This will install the script and set up a Git aliases to invoke the script.

3. **Configure Your Preferences** (Optional):

   Edit the `config.sh` file in the `~/.config/git-conventional-commits`
   directory to set your preferences, such as emoji format, additional commit
   types, etc.

## Usage

  ```bash
  git cm
  ```

This command will start the interactive commit wizard for a standard commit
message.

## Configuration

You can customize the behavior of the script by editing the `config.sh` file.
Available configurations:

- `EMOJI_FORMAT`: Set to `"emoji"` for actual emojis or `"code"` for emoji
  short-codes.

## Dependencies

- `jq`: Command-line JSON processor
- `gum`: A tool for stylish command-line interfaces

The script will attempt to install `jq` and `gum` during the
installation process if not already on your path.