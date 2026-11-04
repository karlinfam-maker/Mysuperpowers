#!/usr/bin/env bash
#
# Создание логотипа Antigravity Marketplace из assets/superpowers-small.svg.
#
# Использование:
#   scripts/render-antigravity-logo.sh [--output PATH]
#
# Создаёт почти чёрный знак Superpowers на белом скруглённом квадрате
# с прозрачными углами, PNG 512x512. Запускайте после изменения superpowers-small.svg;
# tests/antigravity/test-logo.sh обнаруживает устаревший сохранённый PNG.
# Требуется rsvg-convert (Homebrew: librsvg).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SVG="$REPO_ROOT/assets/superpowers-small.svg"
OUTPUT="$REPO_ROOT/assets/antigravity-logo.png"

usage() {
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  echo "Ошибка: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || die "для --output нужен путь"
      OUTPUT="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "неизвестный аргумент: $1"
      ;;
  esac
done

command -v rsvg-convert >/dev/null 2>&1 \
  || die "rsvg-convert не найден в PATH (установите librsvg, например через 'brew install librsvg')"
[[ -r "$SOURCE_SVG" ]] || die "не удалось прочитать исходный знак: $SOURCE_SVG"

# Everything inside the source <svg> element: the mark's paths and ellipse.
mark="$(sed -E 's/^.*<svg[^>]*>//; s#</svg>.*$##' "$SOURCE_SVG")"
[[ -n "$mark" ]] || die "не удалось извлечь знак из $SOURCE_SVG"

# The mark's bounding box is centered at (256,256) in its 512 viewBox and is
# 348 units wide; scale 0.905 makes it ~70% of the 450-unit rounded square.
composed="$(mktemp)"
trap 'rm -f "$composed"' EXIT
cat >"$composed" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <rect x="31" y="31" width="450" height="450" rx="100" ry="100" fill="#ffffff"/>
  <g fill="#1a1a1a" transform="translate(256 256) scale(0.905) translate(-256 -256)">$mark</g>
</svg>
EOF

rsvg-convert -w 512 -h 512 "$composed" -o "$OUTPUT"
echo "wrote $OUTPUT"
