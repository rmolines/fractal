#!/usr/bin/env bash
set -euo pipefail

# session-lock.sh — manage session lock files for fractal predicate tree nodes
# Usage: bash scripts/session-lock.sh <command> [args]
#
# Commands:
#   create <node_rel_path>   — claim a node for this session
#   remove <node_rel_path>   — release this session's lock on a node
#   list                     — list all session locks (including stale)
#   cleanup                  — remove all stale (dead PID) locks
#   check <node_rel_path>    — check if a node has an active lock

# ── Auto-discover tree root ───────────────────────────────────────────────────

if [ ! -d ".fractal" ]; then
  echo "Error: .fractal directory not found. Run from repo root." >&2
  exit 1
fi

if [ -f ".fractal/root.md" ]; then
  TREE_PATH=".fractal"
else
  FOUND=()
  for d in .fractal/*/; do
    [ -f "${d}root.md" ] && FOUND+=("${d%/}")
  done
  if [ "${#FOUND[@]}" -eq 1 ]; then
    TREE_PATH="${FOUND[0]}"
  elif [ "${#FOUND[@]}" -eq 0 ]; then
    echo "Error: no fractal tree found in .fractal/" >&2
    exit 1
  else
    echo "multiple_trees: true"
      for t in "${FOUND[@]}"; do
        echo "tree: $(basename "$t")"
      done
      exit 2
  fi
fi

# ── Helper: extract a frontmatter field from a file ───────────────────────────
# Usage: get_field <file> <field>
get_field() {
  local file="$1"
  local field="$2"
  awk '
    /^---/ { if (fm==0) { fm=1; next } else { exit } }
    fm==1 && /^'"$field"':/ {
      sub(/^'"$field"':[[:space:]]*/, "")
      gsub(/^"/, ""); gsub(/"$/, "")
      gsub(/^'"'"'/, ""); gsub(/'"'"'$/, "")
      print
      exit
    }
  ' "$file"
}

# ── Helper: check if a PID is alive ──────────────────────────────────────────
pid_alive() {
  kill -0 "$1" 2>/dev/null
}

# ── Helper: ISO 8601 timestamp ────────────────────────────────────────────────
iso_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ── Subcommand dispatch ───────────────────────────────────────────────────────

CMD="${1:-}"
if [ -z "$CMD" ]; then
  echo "Usage: bash scripts/session-lock.sh <command> [args]" >&2
  echo "Commands: create, remove, list, cleanup, check" >&2
  exit 1
fi

shift

case "$CMD" in

  # ── create <node_rel_path> ────────────────────────────────────────────────
  create)
    NODE_REL="${1:-}"
    if [ -z "$NODE_REL" ]; then
      echo "Usage: bash scripts/session-lock.sh create <node_rel_path>" >&2
      exit 1
    fi

    NODE_DIR="$TREE_PATH/$NODE_REL"
    if [ ! -d "$NODE_DIR" ]; then
      echo "Error: node directory does not exist: $NODE_DIR" >&2
      exit 1
    fi

    LOCK_FILE="$NODE_DIR/session.lock"
    MY_PID="$PPID"
    SESSION_ID="${CLAUDE_SESSION_ID:-pid-$MY_PID}"

    if [ -f "$LOCK_FILE" ]; then
      EXISTING_PID="$(get_field "$LOCK_FILE" pid)"
      if [ -n "$EXISTING_PID" ]; then
        if [ "$EXISTING_PID" = "$MY_PID" ]; then
          # Same PID — overwrite silently (idempotent)
          :
        elif pid_alive "$EXISTING_PID"; then
          # Different, live PID — node already claimed
          EXISTING_SESSION="$(get_field "$LOCK_FILE" session_id)"
          echo "Error: node '$NODE_REL' is already locked by PID $EXISTING_PID (session: $EXISTING_SESSION)" >&2
          exit 1
        fi
        # else: dead PID — fall through to overwrite (stale lock replacement)
      fi
    fi

    cat > "$LOCK_FILE" <<EOF
---
pid: $MY_PID
session_id: $SESSION_ID
created: $(iso_timestamp)
node: $NODE_REL
---
EOF

    echo "locked: $NODE_REL"
    ;;

  # ── remove <node_rel_path> ────────────────────────────────────────────────
  remove)
    NODE_REL="${1:-}"
    if [ -z "$NODE_REL" ]; then
      echo "Usage: bash scripts/session-lock.sh remove <node_rel_path>" >&2
      exit 1
    fi

    LOCK_FILE="$TREE_PATH/$NODE_REL/session.lock"
    MY_PID="$PPID"

    if [ ! -f "$LOCK_FILE" ]; then
      # Lock doesn't exist — idempotent, no output needed
      echo "unlocked: $NODE_REL"
      exit 0
    fi

    rm -f "$LOCK_FILE"
    echo "unlocked: $NODE_REL"
    ;;

  # ── list ──────────────────────────────────────────────────────────────────
  list)
    FIRST=true
    while IFS= read -r -d '' LOCK_FILE; do
      # Derive relative node path from lock file path
      # LOCK_FILE is like .fractal/node-name/session.lock
      LOCK_DIR="$(dirname "$LOCK_FILE")"
      NODE_REL="${LOCK_DIR#"$TREE_PATH/"}"

      LOCK_PID="$(get_field "$LOCK_FILE" pid)"
      LOCK_SESSION="$(get_field "$LOCK_FILE" session_id)"
      LOCK_CREATED="$(get_field "$LOCK_FILE" created)"

      if pid_alive "$LOCK_PID"; then
        ALIVE="true"
      else
        ALIVE="false"
      fi

      if [ "$FIRST" = true ]; then
        FIRST=false
      else
        echo ""
      fi

      echo "node: $NODE_REL"
      echo "pid: $LOCK_PID"
      echo "session_id: $LOCK_SESSION"
      echo "created: $LOCK_CREATED"
      echo "alive: $ALIVE"
    done < <(find "$TREE_PATH" -name "session.lock" -print0 2>/dev/null | sort -z)
    ;;

  # ── cleanup ───────────────────────────────────────────────────────────────
  cleanup)
    CLEANED=0
    while IFS= read -r -d '' LOCK_FILE; do
      LOCK_PID="$(get_field "$LOCK_FILE" pid)"
      if [ -n "$LOCK_PID" ] && ! pid_alive "$LOCK_PID"; then
        rm -f "$LOCK_FILE"
        CLEANED=$((CLEANED + 1))
      fi
    done < <(find "$TREE_PATH" -name "session.lock" -print0 2>/dev/null)
    echo "cleaned: $CLEANED"
    ;;

  # ── check <node_rel_path> ─────────────────────────────────────────────────
  check)
    NODE_REL="${1:-}"
    if [ -z "$NODE_REL" ]; then
      echo "Usage: bash scripts/session-lock.sh check <node_rel_path>" >&2
      exit 1
    fi

    LOCK_FILE="$TREE_PATH/$NODE_REL/session.lock"

    if [ ! -f "$LOCK_FILE" ]; then
      echo "locked: false"
      exit 0
    fi

    LOCK_PID="$(get_field "$LOCK_FILE" pid)"
    LOCK_SESSION="$(get_field "$LOCK_FILE" session_id)"

    if [ -n "$LOCK_PID" ] && pid_alive "$LOCK_PID"; then
      echo "locked: true"
      echo "pid: $LOCK_PID"
      echo "session_id: $LOCK_SESSION"
    else
      echo "locked: false"
    fi
    ;;

  *)
    echo "Error: unknown command '$CMD'" >&2
    echo "Commands: create, remove, list, cleanup, check" >&2
    exit 1
    ;;

esac
