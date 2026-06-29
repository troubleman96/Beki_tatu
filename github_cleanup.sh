#!/usr/bin/env bash
# ─────────────────────────────────────────────
#  GitHub Repo Cleaner
#  Requires: gh (GitHub CLI) — https://cli.github.com
# ─────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Check dependencies ─────────────────────
if ! command -v gh &>/dev/null; then
  echo -e "${RED}Error:${RESET} GitHub CLI (gh) is not installed."
  echo "Install it from: https://cli.github.com"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo -e "${YELLOW}You're not logged in to GitHub CLI.${RESET}"
  echo "Running: gh auth login"
  gh auth login
fi

# ── Fetch repos ────────────────────────────
echo -e "\n${BOLD}${CYAN}Fetching your repositories...${RESET}\n"

# Gets up to 1000 repos; adjust --limit if you have more
REPOS=$(gh repo list --limit 1000 --json nameWithOwner,isPrivate,updatedAt \
  --jq '.[] | "\(.nameWithOwner)|\(.isPrivate)|\(.updatedAt[:10])"')

if [[ -z "$REPOS" ]]; then
  echo "No repositories found."
  exit 0
fi

# ── Display repos ──────────────────────────
echo -e "${BOLD}Your repositories:${RESET}"
echo "────────────────────────────────────────────────────────"
printf "%-5s %-45s %-10s %-12s\n" "No." "Repository" "Visibility" "Last Updated"
echo "────────────────────────────────────────────────────────"

declare -a REPO_NAMES
i=1
while IFS='|' read -r name is_private updated; do
  REPO_NAMES+=("$name")
  if [[ "$is_private" == "true" ]]; then
    vis="${YELLOW}private${RESET}"
  else
    vis="${GREEN}public ${RESET}"
  fi
  printf "%-5s %-45s " "$i." "$name"
  echo -e "$vis   $updated"
  ((i++))
done <<< "$REPOS"

echo "────────────────────────────────────────────────────────"
echo -e "Total: ${BOLD}${#REPO_NAMES[@]}${RESET} repositories\n"

# ── Select repos to delete ─────────────────
echo -e "${BOLD}Enter the numbers of repos to delete${RESET} (e.g. 1 3 5 or 1-5 or 2,4,6):"
echo -e "${RED}Warning: deletion is permanent and cannot be undone.${RESET}"
read -rp "> " SELECTION

# Parse selection (supports: "1 3 5", "1,3,5", "1-5", or mix)
TO_DELETE=()
for token in $(echo "$SELECTION" | tr ',' ' '); do
  if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    for ((n=${BASH_REMATCH[1]}; n<=${BASH_REMATCH[2]}; n++)); do
      TO_DELETE+=("$n")
    done
  elif [[ "$token" =~ ^[0-9]+$ ]]; then
    TO_DELETE+=("$token")
  fi
done

if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
  echo "No valid selection made. Exiting."
  exit 0
fi

# ── Confirm ────────────────────────────────
echo -e "\n${BOLD}The following repos will be ${RED}permanently deleted${RESET}${BOLD}:${RESET}\n"
for n in "${TO_DELETE[@]}"; do
  idx=$((n - 1))
  if [[ $idx -ge 0 && $idx -lt ${#REPO_NAMES[@]} ]]; then
    echo -e "  ${RED}✗${RESET}  ${REPO_NAMES[$idx]}"
  else
    echo -e "  ${YELLOW}?${RESET}  (skipping invalid number: $n)"
  fi
done

echo ""
read -rp "Type 'yes' to confirm deletion: " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted. No repos were deleted."
  exit 0
fi

# ── Delete ─────────────────────────────────
echo ""
DELETED=0
FAILED=0
for n in "${TO_DELETE[@]}"; do
  idx=$((n - 1))
  if [[ $idx -ge 0 && $idx -lt ${#REPO_NAMES[@]} ]]; then
    repo="${REPO_NAMES[$idx]}"
    echo -n "Deleting $repo ... "
    if gh repo delete "$repo" --yes 2>/dev/null; then
      echo -e "${GREEN}done${RESET}"
      ((DELETED++))
    else
      echo -e "${RED}failed${RESET} (check permissions or repo name)"
      ((FAILED++))
    fi
  fi
done

# ── Summary ────────────────────────────────
echo ""
echo "────────────────────────────────────────"
echo -e "${GREEN}Deleted:${RESET} $DELETED   ${RED}Failed:${RESET} $FAILED"
echo "────────────────────────────────────────"
