# GitHub Repo Cleaner

> **Bulk-delete old, unused, or unwanted GitHub repositories — right from your terminal.**

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Shell: bash](https://img.shields.io/badge/Shell-bash-4EAA25?logo=gnu-bash)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)

---

## Overview

`github_cleanup.sh` is an interactive bash script that lists every repository under your GitHub account (up to 1,000), lets you select which ones to nuke with flexible input syntax, and then permanently deletes them via the [GitHub CLI](https://cli.github.com).

It was built because GitHub doesn't offer a native "select-multiple-and-delete" UI, and manually deleting repos one-by-one through the web is tedious.

A companion helper script, `_GITHUB_AUTH_PERMISSION_4_DELETE.SH`, grants the `delete_repo` OAuth scope to `gh` in one command.

---

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
  - [1. Grant deletion permission (one-time)](#1-grant-deletion-permission-one-time)
  - [2. Run the cleaner](#2-run-the-cleaner)
- [Selection Syntax](#selection-syntax)
- [Screenshots / Walkthrough](#screenshots--walkthrough)
- [How It Works](#how-it-works)
- [Safety](#safety)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Lists all your repos** in a clean numbered table with visibility (public/private) and last-updated date.
- **Flexible selection** — pick repos by number using spaces, commas, ranges (`1-5`), or any combination.
- **Interactive confirmation** — shows you exactly what will be deleted and requires typing `yes` before anything happens.
- **Per-repo feedback** — reports success or failure for each deletion.
- **Summary** — shows total deleted vs. failed at the end.
- **Safe by default** — won't delete anything without explicit `yes` confirmation.
- **No external dependencies besides `gh`** — pure bash, no Python/Node/ruby required.

---

## Prerequisites

- **Bash 4+** (for `declare -a`, `echo -e`, `[[ =~ ]]`). Most modern macOS and Linux systems ship with this.
- **[GitHub CLI (`gh`)](https://cli.github.com)** — the script delegates all API calls to `gh`.

Install `gh` if you don't have it:

```bash
# macOS
brew install gh

# Linux (Ubuntu/Debian)
sudo apt install gh

# Linux (Fedora)
sudo dnf install gh

# Windows (winget)
winget install --id GitHub.cli

# Or download from https://cli.github.com
```

---

## Installation

```bash
# Clone the repo
git clone https://github.com/<your-username>/github-repo-cleaner.git
cd github-repo-cleaner

# Make the script executable
chmod +x github_cleanup.sh
```

That's it. No `npm install`, no `pip`, no `gem`.

---

## Usage

### 1. Grant deletion permission (one-time)

GitHub's API requires the `delete_repo` scope, which `gh` doesn't request by default. Run the helper script once to authorize it:

```bash
./_GITHUB_AUTH_PERMISSION_4_DELETE.SH
# This runs: gh auth refresh -h github.com -s delete_repo
```

A browser window will open asking you to approve the `delete_repo` permission. Approve it.

> **Note:** You only need to do this once per machine. The token is stored securely by `gh`.

### 2. Run the cleaner

```bash
./github_cleanup.sh
```

The script will:

1. Check that `gh` is installed and authenticated (if not, it runs `gh auth login`).
2. Fetch your repos and display them in a numbered table.
3. Prompt you for a selection.
4. Show you which repos are about to be deleted.
5. Ask you to type `yes` to confirm.
6. Delete each repo one-by-one and report results.

---

## Selection Syntax

When prompted `>`, you can enter repo numbers in any of these formats:

| Input         | Effect                          |
|---------------|----------------------------------|
| `1 3 5`       | Delete repos #1, #3, #5          |
| `1,3,5`       | Same as above (commas)           |
| `1-5`         | Delete repos #1 through #5       |
| `1-3 7 9-11`  | Combined range + individual      |
| `1,3-5,8`     | Mixed commas and ranges          |

Invalid numbers are skipped with a warning. Nothing happens unless you type `yes` at the confirmation prompt.

**Example prompt session:**

```
Enter the numbers of repos to delete (e.g. 1 3 5 or 1-5 or 2,4,6):
Warning: deletion is permanent and cannot be undone.
> 2-4 7
```

---

## Screenshots / Walkthrough

```
────────────────────────────────────────────────────────────────────
Fetching your repositories...

Your repositories:
────────────────────────────────────────────────────────────────────
No.   Repository                                       Visibility Last Updated
────────────────────────────────────────────────────────────────────
1.    user/awesome-project                              public     2026-03-15
2.    user/old-test-repo                                private    2022-01-10
3.    user/playground                                   private    2021-11-30
4.    user/archived-thing                               public     2020-06-01
5.    user/deprecated-lib                               public     2019-12-25
────────────────────────────────────────────────────────────────────
Total: 5 repositories

Enter the numbers of repos to delete (e.g. 1 3 5 or 1-5 or 2,4,6):
Warning: deletion is permanent and cannot be undone.
> 2-4

The following repos will be permanently deleted:

  ✗  user/old-test-repo
  ✗  user/playground
  ✗  user/archived-thing

Type 'yes' to confirm deletion: yes
Deleting user/old-test-repo ... done
Deleting user/playground ... done
Deleting user/archived-thing ... done

────────────────────────────────────────────────────
Deleted: 3   Failed: 0
────────────────────────────────────────────────────
```

---

## How It Works

```
┌──────────────────┐
│  gh repo list    │──────► JSON ──► parse into table + array
└──────────────────┘
       │
       ▼
  ┌──────────┐
  │ Display  │  Numbered repo list with visibility & date
  └──────────┘
       │
       ▼
  ┌──────────┐
  │ Prompt   │  User enters selection (spaces, commas, ranges)
  └──────────┘
       │
       ▼
  ┌──────────────┐
  │ Expand range │  "1-3" → [1,2,3]; combine all tokens
  └──────────────┘
       │
       ▼
  ┌──────────────┐
  │ Confirmation │  Show selected repos, require "yes"
  └──────────────┘
       │
       ▼
  ┌──────────────────┐
  │  gh repo delete  │──────► per-repo success/failure output
  └──────────────────┘
       │
       ▼
  ┌──────────┐
  │ Summary  │  Deleted: N   Failed: M
  └──────────┘
```

**Key implementation details:**

- **API call:** `gh repo list --limit 1000 --json nameWithOwner,isPrivate,updatedAt --jq '...'` returns up to 1,000 repos. Bump `--limit` if you have more.
- **Parsing:** Each repo line is pipe-delimited (`nameWithOwner|isPrivate|updatedAt`) and read into a bash array.
- **Range expansion:** Uses bash regex `^([0-9]+)-([0-9]+)$` and a `for` loop to expand ranges like `3-7`.
- **Deletion:** `gh repo delete "$repo" --yes` — the `--yes` flag skips the per-repo confirmation prompt (the script already got a global confirmation from the user).
- **Error handling:** `set -euo pipefail` ensures the script fails fast on unexpected errors. Individual deletion failures are caught and counted without aborting the whole batch.

---

## Safety

- **Nothing is deleted until you type `yes` in full.** Typos like `y`, `Y`, `YES`, `yep` will abort.
- The confirmation step shows every repo that will be deleted — review it carefully.
- The script **never** auto-deletes. It is fully interactive.
- Individual `gh repo delete` failures are caught and counted; the script continues with the remaining repos.
- The `delete_repo` scope is only needed at runtime — you can revoke it afterward in your [GitHub settings](https://github.com/settings/tokens) if desired.

---

## Troubleshooting

| Problem | Likely Cause | Solution |
|---|---|---|
| `gh: command not found` | GitHub CLI not installed | Install from [cli.github.com](https://cli.github.com) |
| `not logged in` / auth errors | Not authenticated | Script auto-runs `gh auth login`, or run it manually |
| `delete_repo` scope missing | Permission not granted | Run `./_GITHUB_AUTH_PERMISSION_4_DELETE.SH` |
| `failed` during deletion | No permission / repo doesn't exist / org restrictions | Check you're an owner of the repo; org repos may have additional protections |
| Not all repos shown | You have >1,000 repos | Edit `--limit 1000` in the script to a higher number |
| Script doesn't run | Not executable | Run `chmod +x github_cleanup.sh` |

---

## Contributing

Contributions are welcome!

- **Found a bug?** Open an issue with steps to reproduce.
- **Want a feature?** Open an issue or submit a PR.
- **Code style:** Keep it pure bash. No new dependencies. Follow `set -euo pipefail` conventions.
- **PR checklist:**
  - Test your changes with a dummy repo or two.
  - Update the README if adding/changing user-facing behavior.
  - Keep commits small and descriptive.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details (or use it freely; it's MIT).

---

## Why "Beki_tatu"?

The repo name is Swahili for "maid-worker"
