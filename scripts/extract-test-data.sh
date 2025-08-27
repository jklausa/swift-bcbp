#!/bin/bash

is_in_repo() {
    # Check for Package.swift (Swift package) and .git directory
    if [ -f "Package.swift" ] && [ -d ".git" ]; then
        return 0
    fi
    return 1
}

# Function to set up output paths based on context
setup_output_paths() {
    if is_in_repo; then
        # We're in the repository - use the test directory
        OUTPUT_DIR="Tests/SwiftBCBPTests/Examples"
        
        # Create the directory if it doesn't exist
        if [ ! -d "$OUTPUT_DIR" ]; then
            echo "Creating output directory: $OUTPUT_DIR"
            mkdir -p "$OUTPUT_DIR"
        fi
        
        ICLOUD_OUTPUT="$OUTPUT_DIR/bcbp-icloud-${USER}.txt"
        LOCAL_OUTPUT="$OUTPUT_DIR/bcbp-local-${USER}.txt"
        echo "Running in repository mode - output will go to $OUTPUT_DIR/"
    else
        # Standalone mode - use current working directory
        ICLOUD_OUTPUT="$PWD/bcbp-icloud-${USER}.txt"
        LOCAL_OUTPUT="$PWD/bcbp-local-${USER}.txt"
        echo "Running in standalone mode - output will go to current directory"
    fi
    echo ""
}

# Set up output paths based on context
setup_output_paths

# Source directories
ICLOUD_DIR="${HOME}/Library/Mobile Documents/com~apple~shoebox/UbiquitousCards"
LOCAL_DIR="${HOME}/Library/Passes/Cards"

# Function to extract BCBP data from a directory
extract_bcbp_data() {
    local source_dir="$1"
    local output_file="$2"
    local source_name="$3"
    
    echo "Scanning ${source_name} passes..."
    find "${source_dir}" -name "pass.json" -exec jq -r '
        # Only process boarding passes (not train tickets, car rentals, etc.)
        select(has("boardingPass"))
        # Filter out Deutsche Bahn train tickets (not BCBP compliant)
        | select(.passTypeIdentifier != "pass.com.deutschebahn.navigator")
        # Filter out Trenitalia (not BCBP)
        | select(.passTypeIdentifier != "pass.com.promptu.ProntoTreno")
        # Filter out Sixt car rental passes (not BCBP compliant)
        | select(.passTypeIdentifier != "pass.com.sixt.reservation")
        # Ensure there is a barcode message (handle both old and new Apple Wallet formats)
        | select((.barcodes[0].message // .barcode.message) != null)
        | select((.barcodes[0].message // .barcode.message) != "")
        # Output format: filepath: barcode_message
        | input_filename + ": " + (.barcodes[0].message // .barcode.message)
    ' {} \; > "${output_file}" 2>/dev/null || true
    
    echo "✓ ${source_name} passes extracted to ${output_file}"
    echo "  Found $(wc -l < "${output_file}" | tr -d ' ') boarding passes"
    echo ""
}

# Show consent notice and get confirmation
echo "=================================================="
echo "PRIVACY NOTICE: BCBP Test Data Extraction"
echo "=================================================="
echo ""
echo "This script will scan your Apple Wallet boarding passes from:"
echo "  1. ${ICLOUD_DIR}"
echo "  2. ${LOCAL_DIR}"
echo ""
echo "The extracted data will contain:"
echo "  - File paths to pass.json files"
echo "  - BCBP barcode data (contains reservation number, flight info,"
echo "    passenger names, frequent flyer number etc.)"
echo ""
echo "Output files will be created at:"
echo "  - ${ICLOUD_OUTPUT}"
echo "  - ${LOCAL_OUTPUT}"
echo ""
echo "This data is relatively sensitive and should be kept private, however"
echo "the only information being extracted is what is contained in the barcode."
echo
echo "You should _never_ post this publicly (especially mid-trip!); but these are"
echo "relatively harmless after a trip is concluded."
echo ""
echo "(unless you're Tony Abbott, then you might be screwed.)"
echo "https://mango.pdf.zone/finding-former-australian-prime-minister-tony-abbotts-passport-number-on-instagram/"
echo ""
echo "Please note that the frequent flyer number, if contained, might be used"
echo "to uniquely identify you, and/or h4x like Tony Abbott."
echo ""
echo "Do you consent to extracting this data? (yes/no): "

# Gonna be perfectly honest, this is way beyond my bash/shell scripting
# knowledge and I let Claude handle this.
# This is needed so that using this script via `curl | sh` work,
# which is required, because I have a bunch of lazy friends who won't give me
# their data unless I make it trivial for them.
if exec 4</dev/tty 2>/dev/null; then
    read consent <&4
    exec 4<&-
else
    read consent
fi
if [ "$consent" != "yes" ]; then
    echo "Extraction cancelled."
    exit 1
fi
echo ""

# Extract data
echo "Extracting BCBP data from boarding passes..."
echo ""

# Extract from both sources
extract_bcbp_data "${ICLOUD_DIR}" "${ICLOUD_OUTPUT}" "iCloud"
extract_bcbp_data "${LOCAL_DIR}" "${LOCAL_OUTPUT}" "local"

echo "Extraction complete!"
