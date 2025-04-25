#!/bin/bash
# build.sh - Static site generator with partials and incremental build
#
# Features:
#  - Recursive processing of HTML from input/ to public/
#  - Uses partials/_head.html, _header.html, _footer.html for page structure
#  - Sets <title> from <body id=""> or filename (hyphens to spaces, title case)
#  - Copies other asset files unchanged
#  - Only processes/copies files that are missing or changed (incremental build)
#  - Injects a JS snippet into HTML footer for live reload (auto refresh)
#  - Options:
#      --clean       : delete public/ folder before building
#      --dry-run     : show planned actions but don't write files
#      --serve       : run python3 http.server on localhost:8000 after build
#      --watch       : watch input/ and partials/ for changes, auto rebuild (needs inotifywait from inotify-tools)
#      --no-refresh  : disable injecting live reload JS
#      --help        : show help
#
# Dependencies:
#  - python3 (for --serve)
#  - inotifywait (for --watch, from inotify-tools package)
#
# Usage examples:
# sh ./build.sh --no-refresh # to process files for distribution.
# sh ./build.sh --serve # to create a server to view the site in a browser. Create a new terminal for further commands.
# sh ./build.sh --watch # to watch for changes and process them as they happen.
# 

set -e

input_dir="input"
partials_dir="partials"
output_dir="public"

# Flags defaults
CLEAN=0
DRY_RUN=0
SERVE=0
WATCH=0
INJECT_REFRESH=1

show_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  --clean       Delete $output_dir/ before building
  --dry-run     Show what would be done without changing files
  --serve       After build, start a simple HTTP server at http://localhost:8000
  --watch       Watch input/ and partials/ for changes and rebuild automatically
                (requires 'inotifywait' from inotify-tools package)
  --no-refresh  Do NOT inject the live reload script into HTML pages
  --help        Show this help message
  Run --serve and --watch in two separate terminals to work on your site.

Notes:
  - The watcher requires 'inotifywait' command (Linux/macOS).
  - The server requires Python 3.
  - Live reload uses a small JS snippet that polls reload.txt in the public folder.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --clean) CLEAN=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --serve) SERVE=1 ;;
    --watch) WATCH=1 ;;
    --no-refresh) INJECT_REFRESH=0 ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Add --help for more info."
      exit 1
      ;;
  esac
  shift
done

echo "Add --help for more info."

# Helper: Title case function (capitalizes first letter of each word)
title_case() {
  echo "$1" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1'
}

# If clean flag, delete the output directory entirely
if [[ $CLEAN -eq 1 ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[Dry-run] Would delete $output_dir/ folder"
  else
    echo "Deleting $output_dir/ folder..."
    rm -rf "$output_dir"
  fi
fi

mkdir -p "$output_dir"

# Read partials once, error if missing
head_partial="$partials_dir/_head.html"
header_partial="$partials_dir/_header.html"
footer_partial="$partials_dir/_footer.html"

for f in "$head_partial" "$header_partial" "$footer_partial"; do
  if [[ ! -f "$f" ]]; then
    echo "Error: Missing partial $f"
    exit 1
  fi
done

# Live reload JS snippet to inject (if enabled)
read -r -d '' live_reload_js <<'EOF' || true
<script>
setInterval(() => {
  fetch("/reload.txt")
    .then(res => res.text())
    .then(text => {
      if (window.lastReload && window.lastReload !== text) {
        location.reload();
      }
      window.lastReload = text;
    });
}, 1000);
</script>
EOF

# Function: Process one HTML file
process_html() {
  local content_file="$1"
  local rel_path="${content_file#$input_dir/}"
  local output_file="$output_dir/$rel_path"

  # Extract <body id="..."> value
  local body_id
  body_id=$(grep -oP '<body[^>]*id="\K[^"]+' "$content_file" || true)

  local title
  if [[ -n "$body_id" ]]; then
    # Replace hyphens with spaces
    title="${body_id//-/ }"
  else
    # Use filename fallback (without extension)
    local filename
    filename=$(basename "$content_file" .html)
    title="${filename//-/ }"
  fi

  # Convert to Title Case
  title=$(title_case "$title")

  # Prepare head with title injected (replace {{TITLE}})
  local head
  head=$(sed "s/{{TITLE}}/$title/" "$head_partial")

  mkdir -p "$(dirname "$output_file")"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[Dry-run] Would process HTML: $rel_path (title: '$title')"
  else
    # Build the output HTML:
    {
      echo "$head"
      cat "$header_partial"
      cat "$content_file"
      cat "$footer_partial"

      # Inject live reload JS before closing body if enabled
      if [[ $INJECT_REFRESH -eq 1 ]]; then
        echo "$live_reload_js"
      fi
    } > "$output_file"

    echo "Processed: $rel_path (title: '$title')"
  fi
}

# Function: Copy one asset file (non-HTML)
copy_asset() {
  local asset="$1"
  local rel_path="${asset#$input_dir/}"
  local dest="$output_dir/$rel_path"

  mkdir -p "$(dirname "$dest")"

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[Dry-run] Would copy asset: $rel_path"
  else
    cp "$asset" "$dest"
    echo "Copied:    $rel_path"
  fi
}

# Main build function (called by watcher and initial build)
build() {
  # Process HTML files (incremental)
  find "$input_dir" -type f -name "*.html" | while read -r file; do
    rel_path="${file#$input_dir/}"
    output_file="$output_dir/$rel_path"

    # Process if output missing or input newer
    if [[ ! -f "$output_file" || "$file" -nt "$output_file" ]]; then
      process_html "$file"
    fi
  done

  # Copy all other files (incremental)
  find "$input_dir" -type f ! -name "*.html" | while read -r file; do
    rel_path="${file#$input_dir/}"
    output_file="$output_dir/$rel_path"

    if [[ ! -f "$output_file" || "$file" -nt "$output_file" ]]; then
      copy_asset "$file"
    fi
  done

  # Update reload.txt timestamp for live reload polling
  if [[ $INJECT_REFRESH -eq 1 && $DRY_RUN -eq 0 ]]; then
    date +%s > "$output_dir/reload.txt"
  fi
}

# Run initial build
build

# Serve function
serve() {
  echo "Starting HTTP server at http://localhost:8000"
  cd "$output_dir"
  python3 -m http.server 8000
}

# Watch function (requires inotifywait)
watch() {
  if ! command -v inotifywait &>/dev/null; then
    echo "Error: inotifywait command not found. Please install inotify-tools."
    exit 1
  fi

  echo "Watching $input_dir/ and $partials_dir/ for changes. Press Ctrl+C to stop."
  inotifywait -r -m "$input_dir" "$partials_dir" -e modify -e create -e delete |
  while read -r path action file; do
    echo "Detected change: $action on $path$file. Rebuilding..."
    build
  done
}

# Handle --watch and --serve options

if [[ $WATCH -eq 1 ]]; then
  # Run watcher (blocks)
  watch
fi

if [[ $SERVE -eq 1 ]]; then
  # If watch also enabled, serve after watcher exit (unlikely)
  # Otherwise serve now (blocking)
  if [[ $WATCH -eq 0 ]]; then
    serve
  fi
fi

