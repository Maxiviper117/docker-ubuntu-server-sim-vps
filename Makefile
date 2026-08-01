.DEFAULT_GOAL := help

ifeq ($(OS),Windows_NT)
RUN_SCRIPT = powershell.exe -NoProfile -ExecutionPolicy Bypass -File helpers/$(1).ps1
PLATFORM_NAME = Windows PowerShell
else
RUN_SCRIPT = bash helpers/$(1).sh
PLATFORM_NAME = Linux or macOS Bash
endif

.PHONY: help setup up status logs shell down reset

help:
	@echo "Detected platform: $(PLATFORM_NAME)"
	@echo ""
	@echo "Available commands:"
	@echo "  make setup   Create or reuse a key, then build and start the simulator"
	@echo "  make up      Build and start the simulator"
	@echo "  make status  Show the simulator status"
	@echo "  make logs    Follow simulator logs"
	@echo "  make shell   Open a shell in the simulator"
	@echo "  make down    Stop the simulator and keep its data"
	@echo "  make reset   Stop the simulator and delete its data"

setup:
	$(call RUN_SCRIPT,setup)

up:
	$(call RUN_SCRIPT,up)

status:
	$(call RUN_SCRIPT,status)

logs:
	$(call RUN_SCRIPT,logs)

shell:
	$(call RUN_SCRIPT,shell)

down:
	$(call RUN_SCRIPT,down)

reset:
	$(call RUN_SCRIPT,reset)
