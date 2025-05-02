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

# Function to extract tags from a single file, properly ignoring code blocks
extract_tags() {
    local file="$1"
    # Use a proper multi-line parser to handle code blocks
    gawk '
    BEGIN { 
        in_code_block = 0
    }
    
    # Record line numbers for debugging
    {
        line_num = NR
    }

    # Detect code block start/end
    /^[ \t]*```/ { 
        in_code_block = !in_code_block
        next
    }
    
    # Process only if not in code block
    !in_code_block {
        # Remove inline code enclosed in backticks
        gsub(/`[^`]*`/, "")
        
        # Remove internal links [[...]]
        gsub(/\[\[.*?\]\]/, "")
        
        # Remove standard markdown links [text](URL)
        gsub(/\[[^\]]*\]\([^\)]*\)/, "")
        
        # Skip lines that are Markdown headings (e.g., "# Heading", "## Subheading")
        if ($0 ~ /^[ \t]*#+[ \t]+/) {
            next
        }
        
        # Use a regex to match valid Obsidian tags
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
        # Use gawk for proper multi-line handling
        gawk -v tag="$search_tag" -v file="$file" '
        BEGIN { 
            in_code_block = 0
            file_has_tag = 0
        }
        
        # Detect code block start/end - allowing for indentation
        /^[ \t]*```/ { 
            in_code_block = !in_code_block
            next
        }
        
        # Process only if not in code block
        !in_code_block {
            # Remove inline code enclosed in backticks
            gsub(/`[^`]*`/, "")
            
            # Remove internal links [[...]]
            gsub(/\[\[.*?\]\]/, "")
            
            # Remove standard markdown links [text](URL)
            gsub(/\[[^\]]*\]\([^\)]*\)/, "")
            
            # Skip lines that are Markdown headings
            if ($0 ~ /^[ \t]*#+[ \t]+/) {
                next
            }
            
            # Check for the specific tag we are searching for
            original_line = $0
            while (match($0, /#[A-Za-z][A-Za-z0-9_-]*/)) {
                current_tag = substr($0, RSTART, RLENGTH)
                current_tag = tolower(current_tag)  # Convert to lowercase for consistency
                if (current_tag == tag) {
                    file_has_tag = 1
                    exit 0  # We found the tag, no need to continue processing the file
                }
                # Remove the matched tag to find subsequent tags in the same line
                $0 = substr($0, RSTART + RLENGTH)
            }
            # Restore the original line for further processing
            $0 = original_line
        }
        
        END {
            if (file_has_tag) {
                print file
            }
        }
        ' "$file" || echo "Error processing $file" >&2
    done | sort | uniq
}

# Debug function to help identify issues with code block detection
debug_file() {
    local file="$1"
    echo "Debugging file: $file"
    
    gawk '
    BEGIN { 
        in_code_block = 0
        print "LINE | CODE_BLOCK | CONTENT"
        print "---- | ---------- | -------"
    }
    
    # Detect code block start/end
    {
        line_num = NR
        
        if ($0 ~ /^[ \t]*```/) {
            in_code_block = !in_code_block
            status = in_code_block ? "START" : "END"
            printf "%-4d | %-10s | %s\n", line_num, status, $0
        } else {
            status = in_code_block ? "INSIDE" : "OUTSIDE"
            printf "%-4d | %-10s | %s\n", line_num, status, $0
        }
    }
    ' "$file"
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
    --debug)
        if [ -z "$2" ]; then
            echo "Error: Please provide a file to debug."
            echo "Usage: $0 --debug <file.md>"
            exit 1
        fi
        debug_file "$2"
        ;;
    *)
        echo "Usage:"
        echo "  $0 --list-tags [output_file]   # List all unique tags, optionally exporting to a file"
        echo "  $0 --search \"#tag\"            # Search for files containing a specific tag"
        echo "  $0 --debug <file.md>           # Debug code block detection in a specific file"
        exit 1
        ;;
esac
