#!/bin/bash

# obsidian_tag_search.sh
# Usage:
#   To list all unique tags:
#     ./obsidian_tag_search.sh --list-tags [output_file]
#   To search for a specific tag:
#     ./obsidian_tag_search.sh --search "#work"

# Set the directory to search
SEARCH_DIR="$HOME/Documents/Zettelkasten"

# Check if SEARCH_DIR exists
if [ ! -d "$SEARCH_DIR" ]; then
    echo "Error: Directory '$SEARCH_DIR' does not exist."
    exit 1
fi

# Function to extract tags from a single file, excluding code blocks, headings, internal links, inline code, and standard markdown links
extract_tags() {
    local file="$1"
    awk '
    BEGIN { 
        in_code = 0 
    }
    /^```/ { 
        in_code = !in_code
        next 
    }
    !in_code {
        # Remove inline code enclosed in backticks
        gsub(/`[^`]*`/, "")
        
        # Remove internal links [[...]]
        gsub(/\[\[.*?\]\]/, "")
        
        # Remove standard markdown links [text](URL)
        gsub(/\[[^\]]*\]\([^\)]*\)/, "")
        
        # Skip lines that are Markdown headings (e.g., "# Heading", "## Subheading")
        if ($0 ~ /^#+[ \t]+/) {
            next
        }
        
        # Use a regex to match tags: # followed by a letter and then letters, numbers, underscores, or hyphens
        while (match($0, /#[A-Za-z][A-Za-z0-9_-]*/)) {
            tag = substr($0, RSTART, RLENGTH)
            # Validate tag: starts with #, followed by letter, contains allowed chars, and does not end with '_'
            if (tag ~ /^#[A-Za-z][A-Za-z0-9_-]*$/ && tag !~ /_$/) {
                tag = tolower(tag)  # Convert to lowercase for consistency
                print tag
            }
            # Remove the matched tag to find subsequent tags in the same line
            $0 = substr($0, RSTART + RLENGTH)
        }
    }
    ' "$file"
}

# Function to list all unique tags, optionally exporting to a file
list_unique_tags() {
    local output_file="$2"
    if [ -n "$output_file" ]; then
        find "$SEARCH_DIR" -type f -name "*.md" -print0 | \
        while IFS= read -r -d '' file; do
            extract_tags "$file"
        done | sort | uniq > "$output_file"
        echo "Tags exported to $output_file"
    else
        find "$SEARCH_DIR" -type f -name "*.md" -print0 | \
        while IFS= read -r -d '' file; do
            extract_tags "$file"
        done | sort | uniq
    fi
}

# Function to search for a specific tag and list files containing it
search_tag() {
    local search_tag="$1"
    if [[ ! "$search_tag" =~ ^# ]]; then
        echo "Error: Tag should start with # (e.g., #work)"
        exit 1
    fi

    search_tag=$(echo "$search_tag" | tr '[:upper:]' '[:lower:]')  # Convert search_tag to lowercase

    echo "Files containing the tag '$search_tag':"
    find "$SEARCH_DIR" -type f -name "*.md" -print0 | \
    while IFS= read -r -d '' file; do
        awk -v tag="$search_tag" '
        BEGIN { 
            in_code = 0 
        }
        /^```/ { 
            in_code = !in_code
            next 
        }
        !in_code {
            # Remove inline code enclosed in backticks
            gsub(/`[^`]*`/, "")
            
            # Remove internal links [[...]]
            gsub(/\[\[.*?\]\]/, "")
            
            # Remove standard markdown links [text](URL)
            gsub(/\[[^\]]*\]\([^\)]*\)/, "")
            
            # Skip lines that are Markdown headings
            if ($0 ~ /^#+[ \t]+/) {
                next
            }
            
            while (match($0, /#[A-Za-z][A-Za-z0-9_-]*/)) {
                current_tag = substr($0, RSTART, RLENGTH)
                current_tag = tolower(current_tag)  # Convert to lowercase for consistency
                if (current_tag == tag) {
                    print FILENAME
                    nextfile
                }
                # Remove the matched tag to find subsequent tags in the same line
                $0 = substr($0, RSTART + RLENGTH)
            }
        }
        ' "$file"
    done | sort | uniq
}

# Parse command-line arguments
case "$1" in
    --list-tags)
        list_unique_tags "$@"
        ;;
    --search)
        if [ -z "$2" ]; then
            echo "Error: Please provide a tag to search for."
            echo "Usage: $0 --search \"#tag\""
            exit 1
        fi
        search_tag "$2"
        ;;
    *)
        echo "Usage:"
        echo "  $0 --list-tags [output_file]   # List all unique tags, optionally exporting to a file"
        echo "  $0 --search \"#tag\"            # Search for files containing a specific tag"
        exit 1
        ;;
esac

