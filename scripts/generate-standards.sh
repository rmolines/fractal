#!/usr/bin/env bash
# generate-standards.sh — inspects a repo and drafts .claude/standards.md
# Usage: generate-standards.sh [target-repo-path] [--write]
# Default target: current directory

set -uo pipefail

# --- Argument parsing ---
TARGET=""
WRITE=false
for arg in "$@"; do
  case "$arg" in
    --write) WRITE=true ;;
    *) TARGET="$arg" ;;
  esac
done
TARGET="${TARGET:-$(pwd)}"
TARGET="${TARGET%/}"  # strip trailing slash

# --- Guard: do not overwrite existing standards.md ---
if [ -f "$TARGET/.claude/standards.md" ]; then
  echo "Warning: $TARGET/.claude/standards.md already exists. Refusing to overwrite." >&2
  exit 0
fi

# --- Helper: emit a detected field line ---
# detected <field> <value> <source>
detected() {
  local field="$1" value="$2" source="$3"
  printf "# detected from %s\n" "${source}"
  printf "%s: %s\n" "${field}" "${value}"
}

# --- Helper: emit an undetected required field ---
# undetected_required <field> <placeholder>
undetected_required() {
  local field="$1" placeholder="$2"
  printf "# %-33s # not detected — fill manually\n" "${field}: ${placeholder}"
}

# --- Helper: emit an undetected optional field ---
# undetected_optional <field> <placeholder>
undetected_optional() {
  local field="$1" placeholder="$2"
  printf "# %-33s # optional\n" "${field}: ${placeholder}"
}

# --- Helper: safe grep — returns empty string instead of failing ---
# safe_grep <pattern> <file>
safe_grep() {
  grep "$1" "$2" 2>/dev/null || true
}

# ============================================================
# Detection helpers
# ============================================================

detect_build() {
  local val=""
  # 1. package.json scripts.build
  if [ -f "$TARGET/package.json" ]; then
    val=$(safe_grep '"build"' "$TARGET/package.json" | head -1 | sed 's/.*"build"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    if [ -n "$val" ]; then
      detected "build" "npm run build" "package.json#scripts.build"
      return
    fi
  fi
  # 2. Makefile build: target
  if [ -f "$TARGET/Makefile" ]; then
    val=$(safe_grep "^build:" "$TARGET/Makefile" | head -1)
    if [ -n "$val" ]; then
      detected "build" "make build" "Makefile#build"
      return
    fi
  fi
  # 3. .claude/project.md build: field
  if [ -f "$TARGET/.claude/project.md" ]; then
    val=$(safe_grep "^build:" "$TARGET/.claude/project.md" | sed 's/^build: //' | head -1)
    if [ -n "$val" ]; then
      detected "build" "$val" ".claude/project.md#build"
      return
    fi
  fi
  undetected_required "build" "<command>"
}

detect_test() {
  local val=""
  # 1. package.json scripts.test
  if [ -f "$TARGET/package.json" ]; then
    val=$(safe_grep '"test"' "$TARGET/package.json" | head -1 | sed 's/.*"test"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    if [ -n "$val" ] && [ "$val" != "echo \"Error: no test specified\" && exit 1" ]; then
      detected "test" "npm test" "package.json#scripts.test"
      return
    fi
  fi
  # 2. Makefile test: target
  if [ -f "$TARGET/Makefile" ]; then
    val=$(safe_grep "^test:" "$TARGET/Makefile" | head -1)
    if [ -n "$val" ]; then
      detected "test" "make test" "Makefile#test"
      return
    fi
  fi
  # 3. .claude/project.md test: field
  if [ -f "$TARGET/.claude/project.md" ]; then
    val=$(safe_grep "^test:" "$TARGET/.claude/project.md" | sed 's/^test: //' | head -1)
    if [ -n "$val" ]; then
      detected "test" "$val" ".claude/project.md#test"
      return
    fi
  fi
  # 4. pytest.ini or pyproject.toml [tool.pytest]
  if [ -f "$TARGET/pytest.ini" ]; then
    detected "test" "pytest" "pytest.ini"
    return
  fi
  if [ -f "$TARGET/pyproject.toml" ]; then
    val=$(safe_grep "\[tool\.pytest" "$TARGET/pyproject.toml" | head -1)
    if [ -n "$val" ]; then
      detected "test" "pytest" "pyproject.toml#tool.pytest"
      return
    fi
  fi
  undetected_required "test" "<command>"
}

detect_lint() {
  local val=""
  # 1. .eslintrc* or .eslintignore
  if compgen -G "$TARGET/.eslintrc*" > /dev/null 2>&1 || [ -f "$TARGET/.eslintignore" ]; then
    detected "lint" "npx eslint ." ".eslintrc"
    return
  fi
  # 2. package.json scripts.lint
  if [ -f "$TARGET/package.json" ]; then
    val=$(safe_grep '"lint"' "$TARGET/package.json" | head -1 | sed 's/.*"lint"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    if [ -n "$val" ]; then
      detected "lint" "npm run lint" "package.json#scripts.lint"
      return
    fi
  fi
  # 3. pyproject.toml [tool.ruff] or [tool.flake8]
  if [ -f "$TARGET/pyproject.toml" ]; then
    val=$(safe_grep "\[tool\.ruff\]" "$TARGET/pyproject.toml" | head -1)
    if [ -n "$val" ]; then
      detected "lint" "ruff check ." "pyproject.toml#tool.ruff"
      return
    fi
    val=$(safe_grep "\[tool\.flake8\]" "$TARGET/pyproject.toml" | head -1)
    if [ -n "$val" ]; then
      detected "lint" "flake8 ." "pyproject.toml#tool.flake8"
      return
    fi
  fi
  undetected_optional "lint" "<command>"
}

detect_type_check() {
  if [ -f "$TARGET/tsconfig.json" ]; then
    detected "type-check" "npx tsc --noEmit" "tsconfig.json"
    return
  fi
  undetected_optional "type-check" "<command>"
}

detect_smoke() {
  local val=""
  if [ -f "$TARGET/.claude/project.md" ]; then
    val=$(safe_grep "^smoke:" "$TARGET/.claude/project.md" | sed 's/^smoke: //' | head -1)
    if [ -n "$val" ]; then
      detected "smoke" "$val" ".claude/project.md#smoke"
      return
    fi
  fi
  undetected_optional "smoke" "<command>"
}

detect_format() {
  # check for commitlint config
  if compgen -G "$TARGET/commitlint.config.*" > /dev/null 2>&1; then
    detected "format" "conventional" "commitlint.config.*"
    return
  fi
  if compgen -G "$TARGET/.commitlintrc*" > /dev/null 2>&1; then
    detected "format" "conventional" ".commitlintrc*"
    return
  fi
  detected "format" "free" "default"
}

detect_branch_prefix() {
  local val=""
  if [ -f "$TARGET/.claude/project.md" ]; then
    val=$(safe_grep "^branch-prefix:" "$TARGET/.claude/project.md" | sed 's/^branch-prefix: //' | head -1)
    if [ -n "$val" ]; then
      detected "branch-prefix" "$val" ".claude/project.md#branch-prefix"
      return
    fi
  fi
  undetected_optional "branch-prefix" "<prefix>"
}

detect_protected_branches() {
  local branches=""
  branches=$(git -C "$TARGET" branch -l main master 2>/dev/null | sed 's/^[* ]*//' | grep -v '^$' || true)
  if [ -n "$branches" ]; then
    echo "# detected from git branch"
    echo "protected-branches:"
    while IFS= read -r branch; do
      echo "- $branch"
    done <<< "$branches"
  else
    printf "# %-33s # optional\n" "protected-branches:"
    printf "# %s\n" "- main"
  fi
}

detect_platform() {
  local val=""
  if [ -f "$TARGET/.claude/project.md" ]; then
    val=$(safe_grep "^platform:" "$TARGET/.claude/project.md" | sed 's/^platform: //' | head -1)
    if [ -n "$val" ]; then
      detected "platform" "$val" ".claude/project.md#platform"
      return
    fi
  fi
  undetected_optional "platform" "<platform>"
}

detect_verify() {
  local val=""
  if [ -f "$TARGET/.claude/project.md" ]; then
    val=$(safe_grep "^verify:" "$TARGET/.claude/project.md" | sed 's/^verify: //' | head -1)
    if [ -n "$val" ]; then
      detected "verify" "$val" ".claude/project.md#verify"
      return
    fi
  fi
  undetected_optional "verify" "<command>"
}

detect_hooks() {
  local found_hooks=()
  # Check .husky/ directory
  if [ -d "$TARGET/.husky" ]; then
    for hook in pre-commit pre-push; do
      if [ -f "$TARGET/.husky/$hook" ]; then
        found_hooks+=(".husky/$hook")
      fi
    done
  fi
  # Check .git/hooks/ for executable (non-sample) hooks
  if [ -d "$TARGET/.git/hooks" ]; then
    for hook in pre-commit pre-push; do
      if [ -f "$TARGET/.git/hooks/$hook" ] && [ -x "$TARGET/.git/hooks/$hook" ]; then
        found_hooks+=(".git/hooks/$hook")
      fi
    done
  fi
  if [ ${#found_hooks[@]} -gt 0 ]; then
    echo "# Pre-existing hooks detected:"
    for h in "${found_hooks[@]}"; do
      echo "# - $h"
    done
  else
    echo "# No pre-existing hooks detected"
  fi
}

# ============================================================
# Generate output
# ============================================================

generate() {
  # Header block (lines 1-5 of template)
  cat <<'HEADER'
# Standards Template
# Copy to .claude/standards.md in your repo and fill in the values.
# Format: key: value on single lines. Section headers: ## Name. Lists: - item.
# Optional fields can be omitted — skills treat absent fields as empty/disabled.
# Add new fields freely; existing grep patterns are unaffected.
HEADER

  echo ""
  echo "## Gates"
  echo "# Commands run before any commit or merge. All must exit 0."
  detect_build
  detect_test
  detect_lint
  detect_type_check
  detect_smoke
  detect_hooks

  echo ""
  echo "## Commit"
  detect_format
  detect_branch_prefix
  undetected_optional "co-author" "<name <email>>"
  detect_protected_branches

  echo ""
  echo "## Code"
  detected "simplify-after-delivery" "false" "default"
  detected "hot-file-preflight" "false" "default"
  detected "staleness-check" "false" "default"
  undetected_optional "max-lines-per-file" "<int>"

  echo ""
  echo "## Deploy"
  detect_platform
  detect_verify
  detected "ci-required" "false" "default"

  echo ""
  echo "## Review"
  echo "# Add project-specific review criteria"
}

# ============================================================
# Output
# ============================================================

if [ "$WRITE" = true ]; then
  mkdir -p "$TARGET/.claude"
  generate > "$TARGET/.claude/standards.md"
  echo "Written to $TARGET/.claude/standards.md" >&2
else
  generate
fi
