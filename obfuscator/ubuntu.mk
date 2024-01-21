DOCKER_TAG := ubuntu-latest
DOCKER_IMAGE := quay.io/linux-whitehat/no-diuid:$(DOCKER_TAG)

GOLANG_VERSION := 1.21.5
BASE_IMAGE ?= quay.io/linux-whitehat/diuid:ubuntu-latest

IMAGE_BASE_NAME := ubuntu
IMAGE_BASE_VERSION := 22.04

.EXPORT_ALL_VARIABLES:

TARGETS := build build-image dockerfile do-load load minify private_key push test

$(TARGETS):
	@$(MAKE) -C . -f Makefile $@

.PHONY: $(TARGETS)
