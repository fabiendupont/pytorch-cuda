# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/pytorch-devel:2.3.0-ubi9-nvcr AS builder

FROM nvcr.io/nvidia/cuda:12.4.1-cudnn-runtime-ubi9

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ENV VIRTUAL_ENV=/workspace/venv

RUN dnf update -y --nobest --nodocs --setopt=install_weak_deps=0 && \
    dnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
        ${PYTHON} ${PYTHON}-pip findutils which && \
    dnf clean all

COPY --from=builder /workspace/venv /workspace/venv

WORKDIR /workspace

ENTRYPOINT ["/usr/bin/bash"]
