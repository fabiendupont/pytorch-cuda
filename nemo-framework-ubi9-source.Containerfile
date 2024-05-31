# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/pytorch:2.3.0-ubi9-source AS builder

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ENV VIRTUAL_ENV=/workspace/venv

ARG NEMO_VERSION=1.23.0

RUN microdnf -y update --nobest --nodocs --setopt=install_weak_deps=0  && \
    microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 git-core && \
    microdnf clean all

WORKDIR /workspace

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${NEMO_VERSION} https://github.com/NVIDIA/NeMo.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    cd /workspace/NeMo && \
    MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

FROM quay.io/fabiendupont/pytorch:2.3.0-ubi9-source

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ENV VIRTUAL_ENV=/workspace/venv

COPY --from=builder /workspace/NeMo/dist/*.whl /tmp/wheel/

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /tmp/wheel/*.whl && \
    rm -rf /tmp/wheel

WORKDIR /workspace
