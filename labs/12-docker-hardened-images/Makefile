.PHONY: up down verify clean help

help:
	@echo "Lab 12: Docker Hardened Images Trust Control Plane"
	@echo ""
	@echo "Targets:"
	@echo "  make up       Bootstrap kind cluster + local registry + Kyverno"
	@echo "  make down     Tear down cluster"
	@echo "  make verify   Verify platform health"
	@echo "  make clean    Remove all artifacts and reset state"

up:
	@./platform/bootstrap.sh

down:
	@./stop.sh

verify:
	@./tools/verify-image.sh dhi.io/python:3.13

clean:
	@./cleanup.sh
