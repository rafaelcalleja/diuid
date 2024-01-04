DOCKER_TAG ?= latest
DOCKER_IMAGE ?= quay.io/linux-whitehat/no-diuid:$(DOCKER_TAG)

GOLANG_VERSION ?= 1.21.5
BASE_IMAGE ?= quay.io/linux-whitehat/diuid:latest

build:
	docker build -t $(DOCKER_IMAGE) \
	--build-arg=GOLANG_VERSION=$(GOLANG_VERSION) \
	--build-arg=BASE_IMAGE=$(BASE_IMAGE) \
 	.
