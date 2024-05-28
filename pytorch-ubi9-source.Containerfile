FROM registry.redhat.io/ubi9/ubi-minimal:9.4 AS builder

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ARG VIRTUAL_ENV=/workspace/venv
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

ARG NVIDIA_DRIVER_STREAM=550
ARG CUDA_VERSION=12.4
ARG CUDA_MAJOR_VERSION=12
ARG CUDA_DASHED_VERSION=12-4
ARG CUDNN_MAJOR_VERSION=9
ARG NCCL_VERSION=2.21.5

ARG PYTORCH_VERSION=2.3.0
ARG PYTORCH_AUDIO_VERSION=2.3.0
ARG PYTORCH_VISION_VERSION=0.18.0

RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    curl -sL -o /etc/yum.repos.d/cuda.repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && \
    microdnf -y module enable nvidia-driver:${NVIDIA_DRIVER_STREAM} && \
    microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
        ${PYTHON} ${PYTHON}-pip ${PYTHON}-devel \
        cargo cmake findutils gcc gcc-c++ git-core openssl-devel rust which \
        ccache \
        cuda-cccl-${CUDA_DASHED_VERSION} \
        cuda-cudart-${CUDA_DASHED_VERSION} cuda-cudart-devel-${CUDA_DASHED_VERSION} \
        cuda-cupti-${CUDA_DASHED_VERSION} \
        cuda-driver-devel-${CUDA_DASHED_VERSION} \
        cuda-nvcc-${CUDA_DASHED_VERSION} \
        cuda-nvml-devel-${CUDA_DASHED_VERSION} \
        cuda-nvprof-${CUDA_DASHED_VERSION} \
        cuda-nvrtc-devel-${CUDA_DASHED_VERSION} \
        cuda-nvrtc-${CUDA_DASHED_VERSION} \
        cuda-nvtx-${CUDA_DASHED_VERSION} \
        cuda-profiler-api-${CUDA_DASHED_VERSION} \
        libcublas-${CUDA_DASHED_VERSION} libcublas-devel-${CUDA_DASHED_VERSION} \
        libcudnn${CUDNN_MAJOR_VERSION}-cuda-${CUDA_MAJOR_VERSION} libcudnn${CUDNN_MAJOR_VERSION}-devel-cuda-${CUDA_MAJOR_VERSION} \
        libcufft-${CUDA_DASHED_VERSION} libcufft-devel-${CUDA_DASHED_VERSION} \
        libcurand-${CUDA_DASHED_VERSION} libcurand-devel-${CUDA_DASHED_VERSION} \
        libcusolver-${CUDA_DASHED_VERSION} libcusolver-devel-${CUDA_DASHED_VERSION} \
        libcusparse-${CUDA_DASHED_VERSION} libcusparse-devel-${CUDA_DASHED_VERSION} \
        libnccl-${NCCL_VERSION}-1+cuda${CUDA_VERSION} libnccl-devel-${NCCL_VERSION}-1+cuda${CUDA_VERSION} \
        libnvfatbin-${CUDA_DASHED_VERSION} libnvfatbin-devel-${CUDA_DASHED_VERSION} \
        libnvjitlink-${CUDA_DASHED_VERSION} libnvjitlink-devel-${CUDA_DASHED_VERSION} \
        libnvjpeg-${CUDA_DASHED_VERSION} libnvjpeg-devel-${CUDA_DASHED_VERSION} \
        libnpp-${CUDA_DASHED_VERSION} libnpp-devel-${CUDA_DASHED_VERSION} \
        nvidia-driver-NVML && \
    microdnf clean all && \
    ${PYTHON} -m venv ${VIRTUAL_ENV}

ENV CCACHE_DIR=/root/.cache/ccache

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    mkdir -p /root/.local/bin && \
    ln -s /usr/bin/ccache /root/.local/bin/gcc && \
    ln -s /usr/bin/ccache /root/.local/bin/g++ && \
    ln -s /usr/bin/ccache /root/.local/bin/cc && \
    ln -s /usr/bin/ccache /root/.local/bin/c++ && \
    ln -s /usr/bin/ccache /root/.local/bin/nvcc && \
    ln -s /usr/bin/ccache /root/.local/bin/cc1plus && \
    ln -s /usr/bin/ccache /root/.local/bin/cicc && \
    ln -s /usr/bin/ccache /root/.local/bin/ptxas && \
    mkdir -p ${CCACHE_DIR} && \
    ccache -s

WORKDIR /workspace

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install numpy pyaml typing_extensions wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_VERSION} https://github.com/pytorch/pytorch.git && \
    cd pytorch && \
    git submodule sync && \
    git submodule update --init --recursive

ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="/usr/local/cuda/lib64:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="/usr/local/cuda/include:${CPLUS_INCLUDE_PATH}"
ENV C_INCLUDE_PATH="/usr/local/cuda/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="/usr/local/cuda/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="/usr/local/cuda/include:${C_INCLUDE_PATH}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    cd /workspace/pytorch && \
    USE_CUDA=1 TORCH_CUDA_ARCH_LIST="7.0 8.0 8.6 9.0" MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /workspace/pytorch/dist/*.whl && \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install ninja

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_AUDIO_VERSION} https://github.com/pytorch/audio.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/audio && \
    PYTORCH_VERSION=$(${VIRTUAL_ENV}/bin/${PYTHON} -m pip show torch | grep 'Version:' | awk '{ print $2; }') TORCH_CUDA_ARCH_LIST="7.0 8.0 8.6 9.0" MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_VISION_VERSION} https://github.com/pytorch/vision.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    microdnf install -y --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        ${PYTHON}-pybind11-devel \
        libjpeg-turbo libjpeg-turbo-devel \
        libpng libpng-devel && \
    microdnf clean all

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    microdnf install -y --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
#        ${PYTHON}-pybind11-devel \
#        ffmpeg-free ffmpeg-free-devel \
#        libswscale-free libswscale-free-devel \
#        libavcodec-free libavcodec-free-devel \
#        libswresample-free libswresample-free-devel \
#        libavformat-free libavformat-free-devel \
#        libavutil-free libavutil-free-devel \
#        libjpeg-turbo libjpeg-turbo-devel \
#        libpng libpng-devel && \
#    microdnf clean all

#ENV C_INCLUDE_PATH="/usr/include/ffmpeg:${C_INCLUDE_PATH}"
#ENV CPLUS_INCLUDE_PATH="/usr/include/ffmpeg:${CPLUS_INCLUDE_PATH}"
#ENV CMAKE_INCLUDE_PATH="/usr/include/ffmpeg:${CMAKE_INCLUDE_PATH}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/vision && \
    PYTORCH_VERSION=$(${VIRTUAL_ENV}/bin/${PYTHON} -m pip show torch | grep 'Version:' | awk '{ print $2; }') TORCH_CUDA_ARCH_LIST="7.0 8.0 8.6 9.0" FORCE_CUDA=1 MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

FROM registry.redhat.io/ubi9/ubi-minimal:9.4

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ARG VIRTUAL_ENV=/workspace/venv
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

ARG NVIDIA_DRIVER_STREAM=550
ARG CUDA_VERSION=12.4
ARG CUDA_MAJOR_VERSION=12
ARG CUDA_DASHED_VERSION=12-4
ARG CUDNN_MAJOR_VERSION=9
ARG NCCL_VERSION=2.21.5

ARG PYTORCH_VERSION=2.3.0
ARG PYTORCH_AUDIO_VERSION=2.3.0
ARG PYTORCH_VISION_VERSION=0.18.0

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    curl -sL -o /etc/yum.repos.d/cuda.repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && \
    microdnf -y module enable nvidia-driver:${NVIDIA_DRIVER_STREAM} && \
    microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
        ${PYTHON} ${PYTHON}-pip findutils which \
        cuda-cccl-${CUDA_DASHED_VERSION} \
        cuda-cudart-${CUDA_DASHED_VERSION} \
        cuda-cupti-${CUDA_DASHED_VERSION} \
        cuda-nvcc-${CUDA_DASHED_VERSION} \
        cuda-nvprof-${CUDA_DASHED_VERSION} \
        cuda-nvrtc-${CUDA_DASHED_VERSION} \
        cuda-nvtx-${CUDA_DASHED_VERSION} \
        libcublas-${CUDA_DASHED_VERSION} \
        libcudnn${CUDNN_MAJOR_VERSION}-cuda-${CUDA_MAJOR_VERSION} \
        libcufft-${CUDA_DASHED_VERSION} \
        libcurand-${CUDA_DASHED_VERSION} \
        libcusolver-${CUDA_DASHED_VERSION} \
        libcusparse-${CUDA_DASHED_VERSION} \
        libnccl-${NCCL_VERSION}-1+cuda${CUDA_VERSION} \
        libnvfatbin-${CUDA_DASHED_VERSION} \
        libnvjitlink-${CUDA_DASHED_VERSION} \
        libnvjpeg-${CUDA_DASHED_VERSION} \
        libnpp-${CUDA_DASHED_VERSION} \
        nvidia-driver-NVML && \
    microdnf clean all && \
    ${PYTHON} -m venv ${VIRTUAL_ENV} && \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install wheel

ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"

COPY --from=builder /workspace/pytorch/dist/*.whl /tmp/wheel/
COPY --from=builder /workspace/audio/dist/*.whl /tmp/wheel/
COPY --from=builder /workspace/vision/dist/*.whl /tmp/wheel/

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /tmp/wheel/*.whl && \
    rm -rf /tmp/wheel

WORKDIR /workspace
ENTRYPOINT ["source", "/workspace/venv/bin/activate"]
