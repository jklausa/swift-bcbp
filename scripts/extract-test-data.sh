#!/bin/bash

# Output files for each source
ICLOUD_OUTPUT="Tests/SwiftBCBPTests/Examples/bcbp-icloud-${USER}.txt"
LOCAL_OUTPUT="Tests/SwiftBCBPTests/Examples/bcbp-local-${USER}.txt"

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
read -p "Do you consent to extracting this data? (yes/no): " consent
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
