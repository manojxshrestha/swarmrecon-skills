#!/usr/bin/env bash
# setup.sh — register the swarmrecon OpenCode skills with OpenCode.
#
# Usage:
#   ./setup.sh                 # validate skills + update OpenCode config
#   ./setup.sh --dry-run       # show what would change, write nothing
#   ./setup.sh --check         # exit 0 only when this repo is registered
#   ./setup.sh --print-config  # print a minimal config snippet
#   ./setup.sh --no-config     # validate the skills only
#
# The script is intentionally conservative: it preserves every existing
# OpenCode setting, backs up the config before writing, and never overwrites an
# invalid JSON file.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.json}"
DRY_RUN=false
CHECK_ONLY=false
PRINT_CONFIG=false
NO_CONFIG=false

log()  { printf '[+] %s\n' "$*"; }
info() { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[-] %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $0 [options]

Register this repository as an OpenCode skills directory.

Options:
  --config <path>   OpenCode config file
                    (default: \$OPENCODE_CONFIG or ~/.config/opencode/opencode.json)
  --dry-run         Validate and show the planned change without writing
  --check           Exit 0 only if this skills directory is already registered
  --print-config    Print a minimal OpenCode config snippet and exit
  --no-config       Validate the skills only; do not touch OpenCode config
  -h, --help        Show this help

Examples:
  ./setup.sh
  ./setup.sh --dry-run
  ./setup.sh --config ~/.config/opencode/opencode.json
  ./setup.sh --check
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --config)
            [ $# -ge 2 ] || die "--config needs a path"
            CONFIG="$2"
            shift 2
            ;;
        --dry-run)       DRY_RUN=true; shift ;;
        --check)         CHECK_ONLY=true; shift ;;
        --print-config)  PRINT_CONFIG=true; shift ;;
        --no-config)     NO_CONFIG=true; shift ;;
        -h|--help)       usage; exit 0 ;;
        *)               usage >&2; die "unknown option: $1" ;;
    esac
done

# Store ~/skills as "~/skills" so the config is portable when possible.
case "$SCRIPT_DIR" in
    "$HOME"/*) SKILLS_ENTRY="~/${SCRIPT_DIR#"$HOME"/}" ;;
    *)         SKILLS_ENTRY="$SCRIPT_DIR" ;;
esac

if $PRINT_CONFIG; then
    printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "skills": ["%s"]\n}\n' "$SKILLS_ENTRY"
    exit 0
fi

info "swarmrecon OpenCode skills — setup"
info "Skills directory: $SCRIPT_DIR"

mapfile -t SKILL_FILES < <(
    find "$SCRIPT_DIR" -mindepth 2 -maxdepth 2 -type f -name SKILL.md -print | sort
)
[ "${#SKILL_FILES[@]}" -gt 0 ] || die "no <skill-id>/SKILL.md files found"

for file in "${SKILL_FILES[@]}"; do
    first="$(head -n 1 "$file" 2>/dev/null || true)"
    [ "$first" = "---" ] || die "missing YAML frontmatter: $file"
    grep -q '^name:' "$file" || die "missing name: in $file"
    grep -q '^description:' "$file" || die "missing description: in $file"
done
log "Validated ${#SKILL_FILES[@]} skills"

if $NO_CONFIG; then
    log "Config not modified (--no-config)."
    exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found; cannot safely edit $CONFIG"
    warn "Add this entry manually:"
    printf '  "skills": ["%s"]\n' "$SKILLS_ENTRY"
    exit 1
fi

if command -v opencode >/dev/null 2>&1; then
    log "OpenCode: $(opencode --version 2>/dev/null | head -n 1 || true)"
else
    warn "opencode is not on PATH; install OpenCode before using the skills"
fi

python3 - "$CONFIG" "$SKILLS_ENTRY" "$DRY_RUN" "$CHECK_ONLY" <<'PY'
import json
import os
import shutil
import sys
from datetime import datetime

config_path, entry, dry_run, check_only = sys.argv[1:5]
dry_run = dry_run == "true"
check_only = check_only == "true"
entry_abs = os.path.abspath(os.path.expanduser(entry))

def norm(value):
    return os.path.abspath(os.path.expanduser(str(value)))

def fail(message):
    print(f"[-] {message}", file=sys.stderr)
    raise SystemExit(1)

if not os.path.exists(config_path):
    if check_only:
        fail(f"not registered: {entry} (config not found: {config_path})")
    data = {
        "$schema": "https://opencode.ai/config.json",
        "skills": [entry],
    }
    changed = True
    created = True
else:
    try:
        with open(config_path, encoding="utf-8") as handle:
            data = json.load(handle)
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {config_path}: {exc}")
    except OSError as exc:
        fail(f"cannot read {config_path}: {exc}")

    if not isinstance(data, dict):
        fail(f"config root must be an object: {config_path}")

    skills = data.get("skills", [])
    if isinstance(skills, str):
        skills = [skills]
    elif not isinstance(skills, list):
        fail(f'"skills" must be a list in {config_path}')

    if any(norm(item) == entry_abs for item in skills):
        print(f"[+] already registered: {entry}")
        print(f"[+] OpenCode config: {config_path}")
        print("[+] Restart OpenCode to reload the skills.")
        raise SystemExit(0)

    if check_only:
        fail(f"not registered: {entry} (config: {config_path})")

    data["skills"] = skills + [entry]
    changed = True
    created = False

if check_only:
    fail(f"not registered: {entry} (config: {config_path})")

if dry_run:
    print(f"[*] would add skills entry: {entry}")
    print(f"[*] would update: {config_path}")
    print("[*] dry run complete — nothing written.")
    raise SystemExit(0)

if not created:
    backup = f"{config_path}.bak.{datetime.now():%Y%m%d-%H%M%S}"
    try:
        shutil.copy2(config_path, backup)
    except OSError as exc:
        fail(f"cannot back up {config_path}: {exc}")
    print(f"[+] backup: {backup}")

parent = os.path.dirname(os.path.abspath(config_path))
if parent:
    os.makedirs(parent, exist_ok=True)

tmp_path = f"{config_path}.tmp"
try:
    with open(tmp_path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")
    os.replace(tmp_path, config_path)
except OSError as exc:
    try:
        os.unlink(tmp_path)
    except OSError:
        pass
    fail(f"cannot write {config_path}: {exc}")

print(f"[+] added skills entry: {entry}")
print(f"[+] OpenCode config: {config_path}")
print("[+] Restart OpenCode to reload the skills.")
PY

log "Setup complete."
info "Example prompt: Use the 'dns-infrastructure' skill to review example.com."
