# Git Conventional Commit CLI Wizard

This script provides an interactive command-line interface for creating
structured and Conventional Commit messages. It integrates with Git, allowing
users to select commit types, scopes, and emojis (or emoji codes) for their
commit messages.

## Features

- *Interactive Commit Creation*: Utilize an interactive CLI to construct your
  commit messages, ensuring adherence to the Conventional Commits standard.
- *Gitmoji Integration*: Make your commit messages more expressive and easier to
  understand at a glance.
- *Custom Commit Types and Scopes*: Extend the standard commit types and scopes
  with your custom ones, tailoring the script to your project's needs.
- *JIRA Issue Integration*: Automatically detects JIRA issue tags on your branch
  and offers to include them in your commit message.
- *VSCode Conventional Commit Compatibility*: Seamlessly integrate with the
  [VSCode Conventional Commit
  Extension](https://marketplace.visualstudio.com/items?itemName=vivaxy.vscode-conventional-commits)
  to facilitate working on a team with different IDEs.

## Demo

[![asciicast](https://asciinema.org/a/rk2NmZ0LEdHFzWWFnvlBakvEA.svg)](https://asciinema.org/a/rk2NmZ0LEdHFzWWFnvlBakvEA)

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

You can customize the behavior of the script by editing the
`~/.config/git-conventional-commits/config.sh` file. Available configurations:

- `AUTO_COMMIT`: When you complete the wizard, should it auto-commit to git?
  (Default: true)
- `CHECK_UNSTAGED`: Set to true (default) to check for unstaged files and offer
  to add them to the commit.
- `CUSTOM_COMMIT_TYPES`: Additional Conventional Commit Types.
- `EMOJI_FORMAT`: Set to `"emoji"` for actual emojis or `"code"` for emoji
  short-codes.
- `INCLUDE_JIRA_ISSUE_SLUG`: Set to true (default) to auto-append a git-trailer
  for JIRA issues.
- `SCOPES`: Pre-defined list of scopes that you use frequently. Note: Scopes are
  also ready from `.vscode/settings.json` for compatibility with the VSCode
  Conventional Commit extension.
- `SHOW_EDITOR`: Show the commit message in the default editor before
  committing. (Default: false)
- `VSCODE_CONVENTIONAL_COMMIT_COMPAT`: Set to true (default) to enable
  compatibility with the VSCode Conventional Commit Extension.

> [!NOTE]
> These configuration settings can also be added to a project-specific config,
> which will override the global configuration. The project-specific config
> should be in the root of your git project and be named `.git_cm`.

## Dependencies

- `git`: Version control system
- `gum`: A tool for stylish command-line interfaces
- `jq`: Command-line JSON processor

The script will attempt to install `jq` and `gum` during the
installation process if not already on your path.
