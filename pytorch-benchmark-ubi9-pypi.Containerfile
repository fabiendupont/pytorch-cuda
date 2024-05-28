FROM quay.io/fabiendupont/pytorch:ubi9-pypi

ARG PYTHON_VERSION=3.11
ENV PYTHON_VERSION=3.11
ENV PYTHON=python${PYTHON_VERSION}
ENV MAX_JOBS=$(nproc)
ENV VIRTUAL_ENV=/workspace/venv

ARG NVIDIA_DRIVER_VERSION=550.54.15
ARG NVIDIA_DRIVER_STREAM=550
ARG CUDA_VERSION=12.4
ARG CUDA_DASHED_VERSION=12-4
ARG NSIGHT_SYSTEMS_VERSION=2024.2.3

RUN curl -sL -o /etc/yum.repos.d/cuda.repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && \
    microdnf -y module enable nvidia-driver:${NVIDIA_DRIVER_STREAM} && \
    microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
        ${PYTHON} ${PYTHON}-pip ${PYTHON}-devel findutils git-core gcc gcc-c++ which

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/opt/nvidia/nsight-systems/${NSIGHT_SYSTEMS_VERSION}/host-linux-x64/Mesa"

RUN --mount=type=cache,id=pipcache,dst=/root/.cache/pip,mode=0777,Z \
    git clone https://github.com/pytorch/benchmark.git && \
    cd benchmark && \
    ${VIRTUAL_ENV}/bin/${PYTHON} install.py

WORKDIR ${VIRTUAL_ENV}/benchmark
