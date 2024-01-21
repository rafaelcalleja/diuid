DOCKER_TAG ?= ubuntu-latest
DOCKER_IMAGE ?= quay.io/linux-whitehat/diuid:$(DOCKER_TAG)

IMAGE_BASE_NAME ?= ubuntu
IMAGE_BASE_VERSION ?= 22.04
KERNEL_VERSION ?= 6.6
GOLANG_VERSION ?= 1.17.6
DOCKER_CHANNEL ?= stable
DOCKER_VERSION ?= 5:24.0.7-1~ubuntu.22.04~jammy
SLIRP4NETNS_VERSION ?= 1.2.2

.EXPORT_ALL_VARIABLES:

TARGETS := build build-info push

$(TARGETS):
	@$(MAKE) -C . -f Makefile $@

.PHONY: $(TARGETS)

.PHONY: obfuscator
obfuscator:
	$(MAKE) -C obfuscator -f ubuntu.mk build
