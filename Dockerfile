FROM fedora
RUN dnf update -y && dnf install -y gcc vim git g++ clang ccache procps-ng \
  nghttp2 curl openssl && \
  dnf clean all

