# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/pytorch:2.3.0-ubi9-source-min

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
        ${PYTHON} ${PYTHON}-pip ${PYTHON}-devel git-core gcc gcc-c++ \
        libjpeg-turbo libpng pango pango-devel \
        cuda-nsight-systems-${CUDA_DASHED_VERSION}

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/opt/nvidia/nsight-systems/${NSIGHT_SYSTEMS_VERSION}/host-linux-x64/Mesa"
RUN echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"

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

WORKDIR /workspace/benchmark
