# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/pytorch:2.3.0-ubi9-source-redist

ARG PYTHON_VERSION=3.11
ENV PYTHON_VERSION=3.11
ENV PYTHON=python${PYTHON_VERSION}
ENV MAX_JOBS=$(nproc)
ENV VIRTUAL_ENV=/workspace/venv

ENV CCACHE_DIR=/root/.cache/ccache

ARG NVIDIA_DRIVER_VERSION=550.54.15
ARG NVIDIA_DRIVER_STREAM=550
ARG CUDA_VERSION=12.4
ARG CUDA_DASHED_VERSION=12-4
ARG NSIGHT_SYSTEMS_VERSION=2024.2.3

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    curl -sL -o /etc/yum.repos.d/cuda.repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && \
    microdnf -y module enable nvidia-driver:${NVIDIA_DRIVER_STREAM} && \
    microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
        ${PYTHON} ${PYTHON}-pip ${PYTHON}-devel git-core gcc gcc-c++ \
        ccache \
        libjpeg-turbo libpng pango pango-devel \
        cuda-nsight-systems-${CUDA_DASHED_VERSION} && \
    microdnf clean all && \
    mkdir -p /root/.local/bin

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ln -s /usr/bin/ccache /root/.local/bin/gcc && \
    ln -s /usr/bin/ccache /root/.local/bin/g++ && \
    ln -s /usr/bin/ccache /root/.local/bin/cc && \
    ln -s /usr/bin/ccache /root/.local/bin/c++ && \
    ln -s /usr/bin/ccache /root/.local/bin/cc1plus

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ln -s /usr/bin/ccache /root/.local/bin/mpiCC && \
    ln -s /usr/bin/ccache /root/.local/bin/mpicc && \
    ln -s /usr/bin/ccache /root/.local/bin/mpic++ && \
    ln -s /usr/bin/ccache /root/.local/bin/mpicxx && \
    ln -s /usr/bin/ccache /root/.local/bin/orteCC && \
    ln -s /usr/bin/ccache /root/.local/bin/ortecc && \
    ln -s /usr/bin/ccache /root/.local/bin/ortec++ && \
    ln -s /usr/bin/ccache /root/.local/bin/ortecxx && \
    ln -s /usr/bin/ccache /root/.local/bin/oshCC && \
    ln -s /usr/bin/ccache /root/.local/bin/oshcc && \
    ln -s /usr/bin/ccache /root/.local/bin/oshc++ && \
    ln -s /usr/bin/ccache /root/.local/bin/oshcxx && \
    ln -s /usr/bin/ccache /root/.local/bin/shmemCC && \
    ln -s /usr/bin/ccache /root/.local/bin/shmemcc && \
    ln -s /usr/bin/ccache /root/.local/bin/shmemc++ && \
    ln -s /usr/bin/ccache /root/.local/bin/shmemmcxx

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ln -s /usr/bin/ccache /root/.local/bin/nvcc && \
    ln -s /usr/bin/ccache /root/.local/bin/cicc && \
    ln -s /usr/bin/ccache /root/.local/bin/ptxas


ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/opt/nvidia/nsight-systems/${NSIGHT_SYSTEMS_VERSION}/host-linux-x64/Mesa"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone https://github.com/facebookresearch/detectron2.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install -e detectron2 && \
    rm -rf detectron2

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth=1 https://github.com/pytorch/benchmark.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/benchmark && \
    ${VIRTUAL_ENV}/bin/${PYTHON} install.py

ENV TORCH_CUDA_ARCH_LIST="7.0 7.5 8.0 8.6 8.7 8.9 9.0"

WORKDIR /workspace/benchmark
