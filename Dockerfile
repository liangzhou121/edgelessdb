FROM ubuntu:24.04 AS build

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  bbe \
  bison \
  build-essential \
  ca-certificates \
  clang-14 \
  cmake \
  git \
  liblz4-dev \
  libncurses-dev \
  libssl-dev \
  ninja-build \
  zlib1g-dev \
  wget

# install golang
ENV GO_VERSION=1.26.1
ENV GO_TAR=go${GO_VERSION}.linux-amd64.tar.gz
RUN wget -q https://go.dev/dl/${GO_TAR} && \
  tar -C /usr/local -xzf ${GO_TAR} && \
  rm ${GO_TAR}
ENV GOROOT=/usr/local/go
ENV GOPATH=/go
ENV PATH=$PATH:$GOROOT/bin:$GOPATH/bin

RUN git config --global http.proxy http://127.0.0.1:8118 && \
  git config --global https.proxy http://127.0.0.1:8118

RUN mkdir ertbuild edbbuild

# download ert codes
ARG erttag=v0.5.2
RUN git clone -b $erttag --depth=1 https://github.com/edgelesssys/edgelessrt
# install ert
RUN cd edgelessrt && export SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct) && cd /ertbuild \
  && cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF /edgelessrt \
  && ninja install

# download edgelessdb codes
RUN git clone --depth=1 https://github.com/liangzhou121/edgelessdb
# build edb
RUN cd edgelessdb && export SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct) && cd /edbbuild \
  && . /opt/edgelessrt/share/openenclave/openenclaverc \
  && cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF /edgelessdb \
  && make -j`nproc` edb-enclave
# sign edb
ARG heapsize=4096
ARG numtcs=64
ARG production=OFF
RUN --mount=type=secret,id=signingkey,dst=/edbbuild/private.pem,required=true \
  cd edbbuild \
  && . /opt/edgelessrt/share/openenclave/openenclaverc \
  && cmake -DHEAPSIZE=$heapsize -DNUMTCS=$numtcs -DPRODUCTION=$production /edgelessdb \
  && make sign-edb \
  && cat edgelessdb-sgx.json

# deploy
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gnupg \
    libcurl4 \
    wget \
    curl

# install dcap
RUN curl -fsSLo /etc/apt/keyrings/intel-sgx-deb.asc https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key
RUN echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/intel-sgx-deb.asc] https://download.01.org/intel-sgx/sgx_repo/ubuntu noble main" \
    | tee /etc/apt/sources.list.d/intel-sgx.list
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsgx-dcap-ql \
    libsgx-dcap-quote-verify \
    libsgx-dcap-default-qpl \
    libsgx-enclave-common-dev\  
    libsgx-dcap-quote-verify-dev \
    libsgx-dcap-ql-dev \
    libsgx-enclave-common \
    libsgx-launch \
    libsgx-urts \
    libsgx-dcap-default-qpl-dev && \
    rm -rf /var/lib/apt/lists/*
RUN sed -i -E 's/"use_secure_cert": true/"use_secure_cert": false/g' /etc/sgx_default_qcnl.conf
RUN sed -i -E 's/localhost:8081/172.19.206.73:8081/g' /etc/sgx_default_qcnl.conf

COPY --from=build /edbbuild/edb /edbbuild/edb-enclave.signed /edbbuild/edgelessdb-sgx.json /edgelessdb/src/entry.sh /
COPY --from=build /opt/edgelessrt/bin/erthost /opt/edgelessrt/bin/
ENV PATH=${PATH}:/opt/edgelessrt/bin
ENTRYPOINT ["/entry.sh"]
EXPOSE 3306 8080
