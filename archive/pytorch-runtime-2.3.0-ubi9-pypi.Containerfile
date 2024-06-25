# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM registry.redhat.io/ubi9/ubi-minimal:9.4 AS builder

ARG PYTHON_VERSION=3.11
ENV PYTHON=python${PYTHON_VERSION}
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV MAX_JOBS=$(nproc)
ENV VIRTUAL_ENV=/workspace/venv

ARG NVIDIA_DRIVER_VERSION=550.54.15
ARG NVIDIA_DRIVER_STREAM=550
ARG CUDA_VERSION=12.4
ARG CUDA_DASHED_VERSION=12-4
ARG NSIGHT_SYSTEMS_VERSION=2024.2.3
ARG PYTORCH_VERSION=2.3.0
ARG PYTORCH_AUDIO_VERSION=2.3.0
ARG PYTORCH_VISION_VERSION=0.18

RUN microdnf update -y --nobest --nodocs --setopt=install_weak_deps=0 && \
    curl -sL -o /etc/yum.repos.d/cuda.repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && \
    microdnf -y module enable nvidia-driver:${NVIDIA_DRIVER_STREAM} && \
    microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
        ${PYTHON} ${PYTHON}-pip ${PYTHON}-devel findutils git-core gcc gcc-c++ which \
        nvidia-driver-NVML cuda-nsight-systems-${CUDA_DASHED_VERSION} && \
    microdnf clean all && \
    ${PYTHON} -m venv ${VIRTUAL_ENV} && \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install pyaml ninja

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/opt/nvidia/nsight-systems/${NSIGHT_SYSTEMS_VERSION}/host-linux-x64/Mesa"

RUN --mount=type=cache,id=pipcache,dst=/root/.cache/pip,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install \
        "torch==${PYTORCH_VERSION}" "torchaudio==${PYTORCH_AUDIO_VERSION}" "torchvision==${PYTORCH_VISION_VERSION}" && \
    find ${VIRTUAL_ENV} -name __pycache__ | xargs rm -rf

FROM registry.redhat.io/ubi9/ubi-minimal:9.4

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ENV VIRTUAL_ENV=/workspace/venv

ARG NVIDIA_DRIVER_STREAM=550
ARG CUDA_DASHED_VERSION=12-4

RUN microdnf update -y --nobest --nodocs --setopt=install_weak_deps=0 && \
    curl -sL -o /etc/yum.repos.d/cuda.repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && \
    microdnf -y module enable nvidia-driver:${NVIDIA_DRIVER_STREAM} && \
    microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
        ${PYTHON} ${PYTHON}-pip findutils which \
        cuda-nsight-systems-${CUDA_DASHED_VERSION} nvidia-driver-NVML && \
    microdnf clean all

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/opt/nvidia/nsight-systems/${NSIGHT_SYSTEMS_VERSION}/host-linux-x64/Mesa"

COPY --from=builder /workspace/venv /workspace/venv

WORKDIR /workspace

ENTRYPOINT ["source", "/workspace/venv/bin/activate"]
