#!/bin/bash
# Processes HTML files from "input", combines with partials from "partials", and writes to "public"
# Title comes from <body id="..."> or falls back to the filename (without extension)

set -e

input_dir="input"
partials_dir="partials"
output_dir="public"

find "$input_dir" -type f -name "*.html" | while read -r content_file; do
    rel_path="${content_file#$input_dir/}"
    output_file="$output_dir/$rel_path"
    mkdir -p "$(dirname "$output_file")"

    # Try to extract body ID
    body_id=$(grep -oP '<body[^>]*id="\K[^"]+' "$content_file")

    if [ -n "$body_id" ]; then
        title=${body_id//-/ }
    else
        # Use filename (without extension) as fallback title
        filename=$(basename "$content_file" .html)
        title=${filename//-/ }
    fi

    # Convert to Title Case
    title=$(echo "$title" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')

    # Build full HTML
    head=$(sed "s/{{TITLE}}/$title/" "$partials_dir/_head.html")

    {
        echo "$head"
        cat "$partials_dir/_header.html"
        cat "$content_file"
        cat "$partials_dir/_footer.html"
    } > "$output_file"

    echo "Generated $output_file with title '$title'"
done

