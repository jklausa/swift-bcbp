# swift-bcbp

A Swift-y printer-parser for BCBP (Bar Coded Boarding Pass) format.

Most other packages usually only support _parsing_ the format, this one explicitly also supports _creating_ the BCBP data.

## Design / Goals

The goal of the project is simple: if you got a Boarding Pass from an airline, this library should be able to parse it.

This means being _extremely_ liberal in accepting misformatted boarding passes, instead of following the BCBP spec closely.

Another goal is to preserve the existing formatting, including out-of-spec behavior, when _printing_ the boarding pass — e.g. you should be able to round-trip between a String, parsed Boarding Pass, back to String and get the _exact same result_.

A "strict" mode, where out-of-specs behavior is corrected when outputting might be added in the future.

## Status

Very much WIP, not ready for any kind of usage.

Based on my personal (300+) collection of boarding passes, which should be plenty of test data; in addition to the reference of the BCBP implementation guide.

## Test data

The _actual_ test data is private for semi-obvious privacy reasons, but can be extracted from your Apple Wallet boarding passes using the provided extraction script.

Some known outliers from my collection, with some data redacted, are included directly in the tests.

### Extracting test data

To extract BCBP data from your boarding passes:

```bash
make extract-test-data
# or directly:
./scripts/extract-test-data.sh
```

This will:
1. Ask for your consent to extract the data
2. Scan boarding passes from known locations on disk
3. Create two output files in `Tests/SwiftBCBPTests/Examples/`:
   - `bcbp-icloud-<username>.txt`  
   - `bcbp-local-<username>.txt` 

### How it works

On macOS, Apple Wallet stores boarding passes in two locations:
- `~/Library/Mobile Documents/com~apple~shoebox/UbiquitousCards` 
- `~/Library/Passes/Cards` 

The extraction script uses `jq` to:
- Filter for actual boarding passes (excludes train tickets, car rentals, etc.)
- Skip known non-BCBP compliant passes (Deutsche Bahn, Sixt)
- Extract the barcode data from each pass

The extracted data contains only the BCBP barcode strings, with the rest of the pass data excluded.

### Customizing the extraction

If your collection contains other non-BCBP compliant passes, you may need to add additional filters to the `extract_bcbp_data` function in `extract-test-data.sh`. 

## Honorable mentions

I relied heavily on:

* https://github.com/bogardpd/flight_log/blob/master/app/classes/boarding_pass.rb
* https://github.com/ncredinburgh/iata-parser/blob/master/src/main/java/com/ncredinburgh/iata/specs/Compartment.java
* https://jia.je/decode-bcbp/
* https://www.flighthistorian.com/boarding-pass

for existing implementation and cross-validating results.

My deepest thanks to the authors of these projects.
