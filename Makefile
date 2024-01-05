DOCKER_TAG ?= latest
DOCKER_IMAGE ?= quay.io/linux-whitehat/diuid:$(DOCKER_TAG)

DEBIAN_VERSION ?= 12.4
KERNEL_VERSION ?= 6.6
GOLANG_VERSION ?= 1.17.6
DOCKER_CHANNEL ?= stable
DOCKER_VERSION ?= 5:24.0.7-1~debian.12~bookworm
SLIRP4NETNS_VERSION ?= 1.2.2

.PHONY: build
build:
	docker build -t $(DOCKER_IMAGE) \
	--build-arg=DEBIAN_VERSION=$(DEBIAN_VERSION) \
	--build-arg=KERNEL_VERSION=$(KERNEL_VERSION) \
	--build-arg=GOLANG_VERSION=$(GOLANG_VERSION) \
	--build-arg=DOCKER_CHANNEL=$(DOCKER_CHANNEL) \
	--build-arg=DOCKER_VERSION=$(DOCKER_VERSION) \
	--build-arg=SLIRP4NETNS_VERSION=$(SLIRP4NETNS_VERSION) \
 	.

.PHONY: obfuscator
obfuscator:
	$(MAKE) -C obfuscator build

test:
	docker run -it --rm $(DOCKER_IMAGE) docker info

push:
	docker push $(DOCKER_IMAGE)

