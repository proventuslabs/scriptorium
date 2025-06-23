# Scriptorium Makefile
# A collection of useful shell functions, scripts and utilities targeting Zsh

.PHONY: help test-lib test-scripts

# Default target
help:
	@echo "Scriptorium - Zsh Plugin Management"
	@echo ""
	@echo "Available targets:"
	@echo "  test-lib          - Run tests for all lib"
	@echo "  test-scripts      - Run tests for all scripts"

test-lib:
	@echo "Running tests for Scriptorium lib..."
	@if command -v shellspec >/dev/null 2>&1; then \
		shellspec --helperdir lib --require spec_helper lib; \
	else \
		echo "ShellSpec not found."; \
		exit 1; \
	fi

test-scripts:
	@echo "Running tests for Scriptorium scripts..."
	@if command -v shellspec >/dev/null 2>&1; then \
		shellspec --helperdir scripts --require spec_helper scripts; \
	else \
		echo "ShellSpec not found."; \
		exit 1; \
	fi
