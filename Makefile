# Makefile for swift-bcbp
.PHONY: build test extract-test-data lint format format-check

# Build the Swift package
build:
	swift build

# Run tests
test:
	swift test -q

# Extract BCBP test data from Apple Wallet passes
extract-test-data:
	@./scripts/extract-test-data.sh

# Run SwiftLint to check code style
lint:
	swift package plugin --allow-writing-to-package-directory swiftlint

# Format code using SwiftFormat
format:
	swift package plugin --allow-writing-to-package-directory swiftformat

# Check formatting without modifying files
format-check:
	swift package plugin --allow-writing-to-package-directory swiftformat --lint
