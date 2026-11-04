#!/usr/bin/env bash
#
# Package the Superpowers Codex plugin as a rootless archive for portal upload.
#
# The Codex portal artifact differs from the old openai/plugins sync flow:
# it is a standalone archive, but it still needs the OpenAI-owned
# skills/*/agents/openai.yaml metadata that used to be preserved from the
# destination plugin repo. Seed that metadata from a prior official package.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REF="HEAD"
OUTPUT=""
FORMAT=""
METADATA_SOURCE=""
ALLOW_DIRTY=0
KEEP_STAGE=0

usage() {
  cat <<'EOF'
Использование:
  scripts/package-codex-plugin.sh [параметры]

Параметры:
  --output PATH            Сохранить архив по указанному пути.
                           По умолчанию: ../_tmp/sup-codex-packaging/superpowers-VERSION.zip
  --format FORMAT          Формат архива: zip или tar.gz. По умолчанию: zip.
                           Если --format не указан, используется расширение
                           --output: .zip, .tar.gz или .tgz.
  --metadata-source PATH   Каталог, .zip или .tar.gz предыдущего официального пакета
                           с исходными skills/*/agents/openai.yaml.
                           По умолчанию: ../_tmp/sup-codex-packaging/superpowers,
                           затем superpowers.zip и superpowers.tar.gz.
  --ref REF                Ссылка Git для упаковки. По умолчанию: HEAD.
  --allow-dirty            Разрешить незакоммиченные изменения; архив строится из --ref.
  --keep-stage             Показать и сохранить временный каталог сборки.
  -h, --help               Показать справку.

В корне архива находятся .codex-plugin/, assets/, skills/, README.md, LICENSE
и CODE_OF_CONDUCT.md. Исходные файлы репозитория, хуки, тесты, документация
и прочие служебные манифесты в архив не включаются.
EOF
}

die() {
  echo "ОШИБКА: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || die "для --output нужен путь"
      OUTPUT="$2"
      shift 2
      ;;
    --format)
      [[ $# -ge 2 ]] || die "для --format нужно значение"
      case "$2" in
        zip)
          FORMAT="zip"
          ;;
        tar.gz|tgz)
          FORMAT="tar.gz"
          ;;
        *)
          die "формат --format должен быть zip или tar.gz"
          ;;
      esac
      shift 2
      ;;
    --metadata-source)
      [[ $# -ge 2 ]] || die "для --metadata-source нужен путь"
      METADATA_SOURCE="$2"
      shift 2
      ;;
    --ref)
      [[ $# -ge 2 ]] || die "для --ref нужно значение"
      REF="$2"
      shift 2
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    --keep-stage)
      KEEP_STAGE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Неизвестный аргумент: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

infer_format_from_output() {
  local output_path="$1"

  case "$output_path" in
    *.tar.gz|*.tgz)
      printf '%s\n' "tar.gz"
      ;;
    *.zip)
      printf '%s\n' "zip"
      ;;
    *)
      return 1
      ;;
  esac
}

if [[ -z "$FORMAT" ]]; then
  FORMAT="$(infer_format_from_output "$OUTPUT" || true)"
  if [[ -z "$FORMAT" ]]; then
    FORMAT="zip"
  fi
else
  output_format="$(infer_format_from_output "$OUTPUT" || true)"
  if [[ -n "$output_format" && "$output_format" != "$FORMAT" ]]; then
    die "расширение --output не соответствует --format $FORMAT: $OUTPUT"
  fi
fi

command -v git >/dev/null || die "git не найден в PATH"
command -v jq >/dev/null || die "jq не найден в PATH"
command -v tar >/dev/null || die "tar не найден в PATH"
command -v gzip >/dev/null || die "gzip не найден в PATH"
command -v shasum >/dev/null || die "shasum не найден в PATH"
if [[ "$FORMAT" == "zip" ]]; then
  command -v zip >/dev/null || die "zip не найден в PATH"
  command -v unzip >/dev/null || die "unzip не найден в PATH"
fi

[[ -e "$REPO_ROOT/.git" ]] || die "корень репозитория не является рабочей копией Git: $REPO_ROOT"
git -C "$REPO_ROOT" rev-parse --verify "$REF^{commit}" >/dev/null ||
  die "ссылка Git не указывает на коммит: $REF"

if [[ "$ALLOW_DIRTY" -ne 1 ]]; then
  dirty_status="$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all)"
  if [[ -n "$dirty_status" ]]; then
    echo "В рабочей копии есть незакоммиченные изменения:" >&2
    printf '%s\n' "$dirty_status" | sed 's/^/  /' >&2
    die "сначала сохраните изменения в коммит или stash либо укажите --allow-dirty для упаковки $REF"
  fi
fi

if [[ -z "$METADATA_SOURCE" ]]; then
  if [[ -d "$REPO_ROOT/../_tmp/sup-codex-packaging/superpowers" ]]; then
    METADATA_SOURCE="$REPO_ROOT/../_tmp/sup-codex-packaging/superpowers"
  elif [[ -f "$REPO_ROOT/../_tmp/sup-codex-packaging/superpowers.zip" ]]; then
    METADATA_SOURCE="$REPO_ROOT/../_tmp/sup-codex-packaging/superpowers.zip"
  elif [[ -f "$REPO_ROOT/../_tmp/sup-codex-packaging/superpowers.tar.gz" ]]; then
    METADATA_SOURCE="$REPO_ROOT/../_tmp/sup-codex-packaging/superpowers.tar.gz"
  else
    die "источник метаданных не найден; укажите --metadata-source <каталог предыдущего пакета, zip или tar.gz>"
  fi
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/superpowers-codex-package.XXXXXX")"
STAGE="$WORK_DIR/payload"
METADATA_WORK="$WORK_DIR/metadata"
ARCHIVE_LIST="$WORK_DIR/archive-list"

cleanup() {
  if [[ "$KEEP_STAGE" -eq 1 ]]; then
    echo "Временный каталог сохранён: $WORK_DIR" >&2
  else
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

mkdir -p "$STAGE" "$METADATA_WORK"

metadata_root_from_dir() {
  local candidate="$1"
  local nested

  if [[ -d "$candidate/skills" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  nested="$(find "$candidate" -mindepth 2 -maxdepth 2 -type d -name skills -print -quit)"
  if [[ -n "$nested" ]]; then
    dirname "$nested"
    return 0
  fi

  return 1
}

prepare_metadata_root() {
  local source="$1"
  local root

  if [[ -d "$source" ]]; then
    root="$(cd "$source" && pwd)"
  elif [[ -f "$source" ]]; then
    case "$source" in
      *.tar.gz|*.tgz)
        tar -xzf "$source" -C "$METADATA_WORK"
        root="$METADATA_WORK"
        ;;
      *.zip)
        command -v unzip >/dev/null || die "unzip не найден в PATH"
        unzip -q "$source" -d "$METADATA_WORK"
        root="$METADATA_WORK"
        ;;
      *)
        die "источник метаданных должен быть каталогом, .zip или .tar.gz: $source"
        ;;
    esac
  else
    die "источник метаданных не существует: $source"
  fi

  metadata_root_from_dir "$root" ||
    die "в источнике метаданных нет каталога skills/: $source"
}

METADATA_ROOT="$(prepare_metadata_root "$METADATA_SOURCE")"

# Pin tar.umask and extract with -p so staged modes are canonical 755/644
# regardless of the builder's git config or process umask.
git -C "$REPO_ROOT" -c tar.umask=0022 archive --format=tar "$REF" -- \
  .codex-plugin \
  CODE_OF_CONDUCT.md \
  LICENSE \
  README.md \
  assets \
  skills \
  | tar -xpf - -C "$STAGE"

VERSION="$(jq -r '.version // empty' "$STAGE/.codex-plugin/plugin.json")"
[[ -n "$VERSION" ]] || die "не удалось прочитать версию из .codex-plugin/plugin.json"

if [[ -z "$OUTPUT" ]]; then
  case "$FORMAT" in
    zip)
      OUTPUT="$REPO_ROOT/../_tmp/sup-codex-packaging/superpowers-$VERSION.zip"
      ;;
    tar.gz)
      OUTPUT="$REPO_ROOT/../_tmp/sup-codex-packaging/superpowers-$VERSION.tar.gz"
      ;;
  esac
fi
mkdir -p "$(dirname "$OUTPUT")"
OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"

missing_metadata=0
while IFS= read -r skill_dir; do
  skill_name="${skill_dir##*/}"
  metadata_file="$METADATA_ROOT/skills/$skill_name/agents/openai.yaml"

  if [[ ! -f "$metadata_file" ]]; then
    echo "Нет метаданных агента OpenAI для навыка: $skill_name" >&2
    missing_metadata=1
    continue
  fi

  mkdir -p "$skill_dir/agents"
  cp "$metadata_file" "$skill_dir/agents/openai.yaml"
done < <(find "$STAGE/skills" -mindepth 1 -maxdepth 1 -type d -print | sort)

if [[ "$missing_metadata" -ne 0 ]]; then
  die "источник метаданных неполон"
fi

skill_count="$(find "$STAGE/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
metadata_count="$(find "$STAGE/skills" -path '*/agents/openai.yaml' -type f | wc -l | tr -d ' ')"
[[ "$skill_count" == "$metadata_count" ]] ||
  die "число метаданных не совпадает: файлов метаданных — $metadata_count, навыков — $skill_count"

(
  cd "$STAGE"
  {
    find . -mindepth 1 -type d | sed 's#^\./##' | LC_ALL=C sort
    find . -mindepth 1 -type f | sed 's#^\./##' | LC_ALL=C sort
  } >"$ARCHIVE_LIST"
)

case "$FORMAT" in
  zip)
    # ZIP cannot represent dates earlier than 1980.
    TZ=UTC find "$STAGE" -exec touch -t 198001010000 {} +
    (
      cd "$STAGE"
      rm -f "$OUTPUT"
      COPYFILE_DISABLE=1 zip -X -q - -@ <"$ARCHIVE_LIST" >"$OUTPUT"
    )
    ;;
  tar.gz)
    # Match the prior official archive's deterministic tar entry metadata:
    # ustar entries with uid/gid 0 and empty uname/gname. GNU tar and bsdtar
    # (macOS) spell those flags differently.
    if tar --version 2>/dev/null | grep -q 'GNU tar'; then
      TAR_METADATA_FLAGS=(--owner=:0 --group=:0 --numeric-owner)
    else
      TAR_METADATA_FLAGS=(--uid 0 --gid 0 --uname '' --gname '')
    fi
    TZ=UTC find "$STAGE" -exec touch -t 197001010000 {} +
    (
      cd "$STAGE"
      rm -f "$OUTPUT"
      COPYFILE_DISABLE=1 tar -cf - --no-recursion --format ustar "${TAR_METADATA_FLAGS[@]}" -T "$ARCHIVE_LIST" |
        gzip -9n >"$OUTPUT"
    )
    ;;
esac

if command -v xattr >/dev/null 2>&1; then
  xattr -c "$OUTPUT" 2>/dev/null || true
fi

case "$FORMAT" in
  zip)
    archive_paths="$(unzip -Z1 "$OUTPUT" | sed 's#/$##')"
    ;;
  tar.gz)
    archive_paths="$(tar -tzf "$OUTPUT")"
    ;;
esac

unexpected_paths="$(
  printf '%s\n' "$archive_paths" |
    grep -E '(^superpowers/|^\.agents/|^hooks/|package\.json$|^\.git|^\.pytest_cache|^\.ruff_cache|^scripts/|^tests/|^docs/|^evals/|^lib/|^\.claude|^\.cursor|^\.kimi|^\.opencode|^\.pi|^AGENTS\.md$|^CLAUDE\.md$|^GEMINI\.md$|^RELEASE-NOTES\.md$|^CHANGELOG\.md$)' || true
)"
if [[ -n "$unexpected_paths" ]]; then
  printf '%s\n' "$unexpected_paths" | sed 's/^/  /' >&2
  die "архив содержит пути, предназначенные только для исходного репозитория"
fi

entry_count="$(printf '%s\n' "$archive_paths" | wc -l | tr -d ' ')"
checksum="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"

echo "Archive: $OUTPUT"
echo "Format:  $FORMAT"
echo "Version: $VERSION"
echo "Entries: $entry_count"
echo "Skills:  $skill_count"
echo "SHA-256: $checksum"
