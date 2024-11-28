{ lib, writeShellApplication, pkgs }:

writeShellApplication {
  name = "rofi-nixossearch";

  runtimeInputs = [ pkgs.nix-search-cli pkgs.jq ];

  text = ''
#!/usr/bin/env bash

# Path to nix-search (ensure it's installed and accessible)
NIX_SEARCH="nix-search"

# Check if nix-search is installed
if ! command -v "$NIX_SEARCH" &> /dev/null; then
    echo "Error: nix-search is not installed or not in PATH."
    exit 1
fi

# Helper function to display a message in rofi
rofi_message() {
    echo "$1" | rofi -dmenu -p "Message:" -kb-cancel "Escape"
}

# Main menu loop
while true; do
    # Get the search query from rofi
    QUERY=$(rofi -dmenu -p "Search NixOS packages:" -kb-cancel "Escape" || echo "__exit__")

    # Exit if Escape was pressed or no input was provided
    if [[ "$QUERY" == "__exit__" || -z "$QUERY" ]]; then
        exit 0
    fi

    # Use nix-search to search for packages, and preprocess into a valid JSON array
    RAW_RESULTS=$($NIX_SEARCH -j -m 10 "$QUERY" | jq -s '.')

    # Check if there are results
    RESULTS=$(echo "$RAW_RESULTS" | jq -r '.[] | "\(.package_pname) (\(.package_pversion)) - \(.package_description)"')
    if [[ -z "$RESULTS" ]]; then
        rofi_message "No packages found for query: $QUERY"
        continue
    fi

    # Show the results in rofi and capture the selected package
    while true; do
        SELECTED=$(echo -e "Go Back\n$RESULTS" | rofi -dmenu -i -p "Select a package:" -kb-cancel "Escape" || echo "__exit__")

        # Exit or go back if Escape is pressed or "Go Back" is selected
        if [[ "$SELECTED" == "__exit__" || -z "$SELECTED" || "$SELECTED" == "Go Back" ]]; then
            break
        fi

        # Parse selected package details
        PACKAGE_PNAME=$(echo "$SELECTED" | awk -F ' ' '{print $1}')
        PACKAGE_DETAILS=$(echo "$RAW_RESULTS" | jq --arg pname "$PACKAGE_PNAME" '.[] | select(.package_pname == $pname)')

        # Extract details from the selected package
        PACKAGE_DESCRIPTION=$(echo "$PACKAGE_DETAILS" | jq -r '.package_description')
        PACKAGE_VERSION=$(echo "$PACKAGE_DETAILS" | jq -r '.package_pversion')
        PACKAGE_HOMEPAGE=$(echo "$PACKAGE_DETAILS" | jq -r '.package_homepage[0]')
        PACKAGE_LICENSE=$(echo "$PACKAGE_DETAILS" | jq -r '.package_license[].fullName')
        PACKAGE_ATTR_NAME=$(echo "$PACKAGE_DETAILS" | jq -r '.package_attr_name')

        # Display actions in rofi
        while true; do
            ACTION=$(echo -e "Go Back\nDetails\nOpen Homepage\nView on NixOS Search" | rofi -dmenu -i -p "Action for $PACKAGE_PNAME:" -kb-cancel "Escape" || echo "__exit__")

            # Exit or go back if Escape is pressed or "Go Back" is selected
            if [[ "$ACTION" == "__exit__" || -z "$ACTION" || "$ACTION" == "Go Back" ]]; then
                break
            fi

            # Perform the selected action
            if [[ "$ACTION" == "Details" ]]; then
                DETAILS_TEXT="Name: $PACKAGE_PNAME
Version: $PACKAGE_VERSION
Description: $PACKAGE_DESCRIPTION
License(s): $PACKAGE_LICENSE"
                rofi_message "$DETAILS_TEXT"
            elif [[ "$ACTION" == "Open Homepage" ]]; then
                if [[ -n "$PACKAGE_HOMEPAGE" ]]; then
                    xdg-open "$PACKAGE_HOMEPAGE" &>/dev/null
                else
                    rofi_message "No homepage available for $PACKAGE_PNAME"
                fi
            elif [[ "$ACTION" == "View on NixOS Search" ]]; then
                PACKAGE_URL="https://search.nixos.org/packages?channel=stable&show=''${PACKAGE_ATTR_NAME}"
                xdg-open "$PACKAGE_URL" &>/dev/null
            fi
        done
    done
done

  '';
}
