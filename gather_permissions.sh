#!/bin/bash

# Function to get permissions of a directory
get_permissions() {
    local dir=$1
    stat -c "%a" "$dir"
}

# Function to get owner of a directory
get_owner() {
    local dir=$1
    stat -c "%U" "$dir"
}

# Function to get group of a directory
get_group() {
    local dir=$1
    stat -c "%G" "$dir"
}

# Function to convert permissions to JSON format
to_json() {
    local dir=$1
    local permissions=$(get_permissions "$dir")
    local owner=$(get_owner "$dir")
    local group=$(get_group "$dir")
    echo "{\"FullPath\": \"$dir\", \"permissions\": \"$permissions\", \"owner\": \"$owner\", \"group\": \"$group\"}"
}

# Main script
main() {
    # Get parent directory from user if not provided as argument
    if [ $# -eq 0 ]; then
        echo "Please enter the parents FullPath:"
        read -r PARENT_DIR
    else
        PARENT_DIR=$1
    fi

    # Check if directory exists
    if [ ! -d "$PARENT_DIR" ]; then
        echo "FullPath does not exist."
        exit 1
    fi

    # Create JSON file
    JSON_FILE="permissions.json"
    echo "[" > $JSON_FILE

    # Get permissions for each directory
    find "$PARENT_DIR" -type d | while read -r dir; do
        json=$(to_json "$dir")
        echo "$json," >> $JSON_FILE
    done

    # Remove trailing comma and close JSON array
    sed -i '$ s/,$//' $JSON_FILE
    echo "]" >> $JSON_FILE

    echo "Permissions have been saved to $JSON_FILE."
}

main "$@"