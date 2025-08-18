# Makefile for swift-bcbp
.PHONY: build test extract-test-data

# Build the Swift package
build:
	swift build

# Run tests
test:
	swift test

# Extract BCBP test data from Apple Wallet passes
extract-test-data:
	@./scripts/extract-test-data.sh