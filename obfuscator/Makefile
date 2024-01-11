CURRENT_DIR := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))

DOCKER_TAG ?= latest
DOCKER_IMAGE ?= quay.io/linux-whitehat/no-diuid:$(DOCKER_TAG)

GOLANG_VERSION ?= 1.21.5
BASE_IMAGE ?= quay.io/linux-whitehat/diuid:latest

DEBIAN_VERSION ?= 12.4

.PHONY: build
build: load

.PHONY: build-image
build-image:
	docker build -t $(DOCKER_IMAGE) \
	--build-arg=GOLANG_VERSION=$(GOLANG_VERSION) \
	--build-arg=BASE_IMAGE=$(BASE_IMAGE) \
 	.

.PHONY: minify
minify: dockerfile
	tar -cf - temp.Dockerfile | gzip -9 | docker run --rm  \
	--interactive -v $$(pwd):/workspace gcr.io/kaniko-project/executor:debug \
	--cleanup \
	--dockerfile=temp.Dockerfile \
	--context tar://stdin \
	--single-snapshot \
	--destination=$(DOCKER_IMAGE) \
	--tar-path=image.tar \
	--snapshot-mode=redo \
	--use-new-run \
	--no-push && \
	rm -rf temp.Dockerfile

.PHONY: load
load: build-image push minify do-load

do-load:
	docker load --input image.tar && rm -rf image.tar

test:
	docker run -it --rm $(DOCKER_IMAGE) docker info

push:
	docker push $(DOCKER_IMAGE)

.PHONY: dockerfile
dockerfile:
	echo "FROM $(DOCKER_IMAGE) as builder\nFROM debian:$(DEBIAN_VERSION)\n" > temp.Dockerfile && \
	echo "COPY --from=builder /usr /usr\nCOPY --from=builder /bin /bin" >> temp.Dockerfile && \
	echo "COPY --from=builder /etc /etc\nCOPY --from=builder /lib64 /lib64" >> temp.Dockerfile && \
	echo "COPY --from=builder /var /var\nCOPY --from=builder /home /home" >> temp.Dockerfile && \
	echo "COPY --from=builder /root /root\nCOPY --from=builder /entrypoint.sh /entrypoint.sh\n" >> temp.Dockerfile && \
	echo "COPY --from=builder /umlshm /umlshm\nCOPY --from=builder /persistent /persistent\n" >> temp.Dockerfile && \
	$(CURRENT_DIR)/dockerfile-from-image.sh $(BASE_IMAGE) >> temp.Dockerfile


KEY_NAME ?= diud
PRIVATE_KEY := $(shell gpg --export-secret-keys --armor $(KEY_NAME)|base64 |  tr -d '\n')

private_key:
	@echo $(PRIVATE_KEY)