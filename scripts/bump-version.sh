#!/usr/bin/env bash
#
# bump-version.sh — bump version numbers across all declared files,
# with drift detection and repo-wide audit for missed files.
#
# Usage:
#   bump-version.sh <new-version>   Bump all declared files to new version
#   bump-version.sh --check         Report current versions (detect drift)
#   bump-version.sh --audit         Check + grep repo for old version strings
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/.version-bump.json"

if [[ ! -f "$CONFIG" ]]; then
  echo "Ошибка: .version-bump.json не найден: $CONFIG" >&2
  exit 1
fi

# --- helpers ---

# Read a dotted field path from a JSON file.
# Handles both simple ("version") and nested ("plugins.0.version") paths.
read_json_field() {
  local file="$1" field="$2"
  # Convert dot-path to jq path: "plugins.0.version" -> .plugins[0].version
  local jq_path
  jq_path=$(echo "$field" | sed -E 's/\.([0-9]+)/[\1]/g' | sed 's/^/./' | sed 's/\.\././g')
  jq -r "$jq_path" "$file"
}

# Write a dotted field path in a JSON file, preserving formatting.
write_json_field() {
  local file="$1" field="$2" value="$3"
  local jq_path
  jq_path=$(echo "$field" | sed -E 's/\.([0-9]+)/[\1]/g' | sed 's/^/./' | sed 's/\.\././g')
  local tmp="${file}.tmp"
  jq "$jq_path = \"$value\"" "$file" > "$tmp" && mv "$tmp" "$file"
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Ошибка: необходимый инструмент '$1' не найден в PATH" >&2
    return 1
  }
}

read_yaml_field() {
  local file="$1" field="$2"
  require_tool yq || return 1
  FIELD="$field" yq -er '.[strenv(FIELD)] | select(tag == "!!str")' "$file"
}

write_yaml_field() {
  local file="$1" field="$2" value="$3"
  FIELD="$field" VALUE="$value" \
    yq -i '.[strenv(FIELD)] = strenv(VALUE)' "$file"
}

read_manifest_field() {
  local file="$1"

  case "$file" in
    *.json) read_json_field "$@" ;;
    *.yaml) read_yaml_field "$@" ;;
    *)
      echo "Ошибка: неподдерживаемый формат манифеста: $file" >&2
      return 1
      ;;
  esac
}

write_manifest_field() {
  local file="$1"

  case "$file" in
    *.json) write_json_field "$@" ;;
    *.yaml) write_yaml_field "$@" ;;
    *)
      echo "Ошибка: неподдерживаемый формат манифеста: $file" >&2
      return 1
      ;;
  esac
}

# Read the list of declared files from config.
# Outputs lines of "path<TAB>field"
declared_files() {
  jq -r '.files[] | "\(.path)\t\(.field)"' "$CONFIG"
}

preflight_manifests() {
  local path field fullpath

  require_tool jq || return 1
  while IFS=$'\t' read -r path field; do
    fullpath="$REPO_ROOT/$path"
    [[ -f "$fullpath" ]] || continue

    if ! read_manifest_field "$fullpath" "$field" >/dev/null; then
      echo "Ошибка: не удалось прочитать объявленный манифест: $path ($field)" >&2
      return 1
    fi
  done < <(declared_files)
}

# Read the audit exclude patterns from config.
audit_excludes() {
  jq -r '.audit.exclude[]' "$CONFIG" 2>/dev/null
}

# --- commands ---

cmd_check() {
  local has_drift=0
  local versions=()

  echo "Проверка версий:"
  echo ""

  while IFS=$'\t' read -r path field; do
    local fullpath="$REPO_ROOT/$path"
    if [[ ! -f "$fullpath" ]]; then
      printf "  %-45s  MISSING\n" "$path ($field)"
      has_drift=1
      continue
    fi
    local ver
    ver=$(read_manifest_field "$fullpath" "$field")
    printf "  %-45s  %s\n" "$path ($field)" "$ver"
    versions+=("$ver")
  done < <(declared_files)

  echo ""

  # Check if all versions match
  local unique
  unique=$(printf '%s\n' "${versions[@]}" | sort -u | wc -l | tr -d ' ')
  if [[ "$unique" -gt 1 ]]; then
    echo "ОБНАРУЖЕНО РАСХОЖДЕНИЕ — версии не совпадают:"
    printf '%s\n' "${versions[@]}" | sort | uniq -c | sort -rn | while read -r count ver; do
      echo "  $ver (файлов: $count)"
    done
    has_drift=1
  else
    echo "Все объявленные файлы согласованы: ${versions[0]}"
  fi

  return $has_drift
}

cmd_audit() {
  # First run check
  cmd_check || true
  echo ""

  # Determine the current version (most common across declared files)
  local current_version
  current_version=$(
    while IFS=$'\t' read -r path field; do
      local fullpath="$REPO_ROOT/$path"
      [[ -f "$fullpath" ]] && read_manifest_field "$fullpath" "$field"
    done < <(declared_files) | sort | uniq -c | sort -rn | head -1 | awk '{print $2}'
  )

  if [[ -z "$current_version" ]]; then
    echo "Ошибка: не удалось определить текущую версию" >&2
    return 1
  fi

  echo "Аудит: поиск версии '$current_version' в репозитории..."
  echo ""

  # Build grep exclude args
  local -a exclude_args=()
  while IFS= read -r pattern; do
    exclude_args+=("--exclude=$pattern" "--exclude-dir=$pattern")
  done < <(audit_excludes)

  # Also always exclude binary files and .git
  exclude_args+=("--exclude-dir=.git" "--exclude-dir=node_modules" "--binary-files=without-match")

  # Get list of declared paths for comparison
  local -a declared_paths=()
  while IFS=$'\t' read -r path _field; do
    declared_paths+=("$path")
  done < <(declared_files)

  # Grep for the version string, but not inside a longer number such as an
  # IP address; a "v" prefix or surrounding quotes still match.
  local version_pattern="(^|[^0-9.])${current_version//./\\.}([^0-9]|$)"
  local found_undeclared=0
  while IFS= read -r match; do
    local match_file
    match_file=$(echo "$match" | cut -d: -f1)
    # Make path relative to repo root
    local rel_path="${match_file#$REPO_ROOT/}"

    # Check if this file is in the declared list
    local is_declared=0
    for dp in "${declared_paths[@]}"; do
      if [[ "$rel_path" == "$dp" ]]; then
        is_declared=1
        break
      fi
    done

    if [[ "$is_declared" -eq 0 ]]; then
      if [[ "$found_undeclared" -eq 0 ]]; then
        echo "НЕОБЪЯВЛЕННЫЕ файлы с версией '$current_version':"
        found_undeclared=1
      fi
      echo "  $match"
    fi
  done < <(grep -rnE "${exclude_args[@]}" "$version_pattern" "$REPO_ROOT" 2>/dev/null || true)

  if [[ "$found_undeclared" -eq 0 ]]; then
    echo "Необъявленных файлов с этой версией нет. Проверка пройдена."
  else
    echo ""
    echo "Проверьте файлы выше: если их нужно обновлять, добавьте в .version-bump.json"
    echo "Чтобы пропускать их, добавьте в список audit.exclude."
  fi
}

cmd_bump() {
  local new_version="$1"

  # Validate semver-ish format
  if ! echo "$new_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    echo "Ошибка: '$new_version' не похоже на номер версии (ожидается X.Y.Z)" >&2
    exit 1
  fi

  preflight_manifests

  echo "Обновление всех объявленных файлов до версии $new_version..."
  echo ""

  while IFS=$'\t' read -r path field; do
    local fullpath="$REPO_ROOT/$path"
    if [[ ! -f "$fullpath" ]]; then
      echo "  ПРОПУЩЕН (отсутствует): $path"
      continue
    fi
    local old_ver
    old_ver=$(read_manifest_field "$fullpath" "$field")
    write_manifest_field "$fullpath" "$field" "$new_version"
    printf "  %-45s  %s -> %s\n" "$path ($field)" "$old_ver" "$new_version"
  done < <(declared_files)

  echo ""
  echo "Готово. Проверяем, не пропущены ли файлы..."
  echo ""
  cmd_audit
}

# --- main ---

case "${1:-}" in
  --check)
    cmd_check
    ;;
  --audit)
    cmd_audit
    ;;
  --help|-h|"")
    echo "Использование: bump-version.sh <new-version> | --check | --audit"
    echo ""
    echo "  <new-version>  Обновить все объявленные файлы до указанной версии"
    echo "  --check        Показать текущие версии и обнаружить расхождения"
    echo "  --audit        Проверить версии и найти необъявленные ссылки на версию"
    exit 0
    ;;
  --*)
    echo "Ошибка: неизвестный параметр '$1'" >&2
    exit 1
    ;;
  *)
    cmd_bump "$1"
    ;;
esac
