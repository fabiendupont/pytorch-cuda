# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4

ARG NVIDIA_SOURCE_IMAGE_REPOSITORY=nvcr.io/nvidia
ARG NVIDIA_SOURCE_IMAGE_NAME=pytorch-pb24h1
ARG NVIDIA_SOURCE_IMAGE_TAG=24.03.02-py3

ARG RHEL_MINOR_VERSION=9.4
ARG RHEL_MAJOR_VERSION=9
ARG CUDA_VERSION=12.4.1

FROM ${NVIDIA_SOURCE_IMAGE_REPOSITORY}/${NVIDIA_SOURCE_IMAGE_NAME}:${NVIDIA_SOURCE_IMAGE_TAG} AS source

#FROM nvcr.io/nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubi${RHEL_MAJOR_VERSION}
FROM registry.redhat.io/ubi9/ubi-minimal:${RHEL_MINOR_VERSION}

ARG RHEL_MAJOR_VERSION=9

ARG CUDA_VERSION=12.4.1
ARG CUDA_DASHED_VERSION=12-4
ARG CUDA_MAJOR_VERSION=12
ARG CUDNN_MAJOR_VERSION=9
ARG NSIGHT_COMPUTE_VERSION=2024.1.1

ARG PYTHON_VERSION=3.11
ENV PYTHON=python${PYTHON_VERSION}
ENV VIRTUAL_ENV=/opt/${PYTHON}/venv
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

ARG GCC_TOOLSET_VERSION=13

ARG PYTORCH_VERSION=2.3.0
ARG PYTORCH_AUDIO_VERSION=2.3.0
ARG PYTORCH_TEXT_VERSION=0.18.0
ARG PYTORCH_VISION_VERSION=0.18.1
ARG NVIDIA_FUSER_VERSION=0.0.13

RUN sed -i "s/enabled=.*/enabled=0/" /etc/yum.repos.d/ubi.repo && \
    sed -i "s/best=.*/best=False/" /etc/dnf/dnf.conf && \
    echo "install_weak_deps=False" >> /etc/dnf/dnf.conf

RUN microdnf update -y --nodocs && \
    microdnf install -y --nodocs \
        alsa-lib \
        alsa-lib-devel \
        asciidoc \
        atlas \
        atlas-devel \
        autoconf \
        automake \
        bzip2 \
        bzip2-devel \
        cargo \
        cmake \
        compat-openssl11 \
        docbook-dtds \
        docbook-style-xsl \
        file \
        findutils \
        gcc-toolset-${GCC_TOOLSET_VERSION} \
        git-core \
        glibc-devel \
        glibc-headers \
        gnupg2 \
        jq \
        libffi-devel \
        libjpeg-turbo-devel \
        libstdc++-devel \
        libtool \
        libuuid-devel \
        libxslt \
        libyaml-devel \
        make \
        ncurses-devel \
        ninja-build \
        pango \
        pango-devel \
        ${PYTHON} \
        ${PYTHON}-devel \
        ${PYTHON}-pybind11-devel \
        ${PYTHON}-pip \
        readline-devel \
        sudo \
        tk-devel \
        unzip \
        valgrind \
        vim \
        wget \
        which \
    && \
    microdnf clean all && \
    ${PYTHON} -m venv ${VIRTUAL_ENV}

RUN microdnf install -y --nodocs --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        gdbm-devel \
        libsndfile-devel \
        lmdb-devel \
        protobuf-compiler \
        protobuf-c-devel \
        snappy-devel \
    && \
    microdnf clean all
RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    microdnf install -y --nodocs --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        ccache \
        ffmpeg-free \
        ffmpeg-free-devel \
        gflags-devel \
        glog-devel \
        hiredis-devel \
        jemalloc \
        lcov \
        leveldb-devel \
        libavcodec-free \
        libavcodec-free-devel \
        libavformat-free \
        libavformat-free-devel \
        libavutil-free \
        libavutil-free-devel \
        libsqlite3x-devel \
        libswresample-free \
        libswresample-free-devel \
        libswscale-free \
        libswscale-free-devel \
        opencv \
        opencv-devel \
    && \
    microdnf clean all && \
    mkdir -p /root/.cache/ccache && \
    mkdir -p /root/.local/bin

ENV PATH=/root/.local/bin:${PATH}

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ln -s /usr/bin/ccache /root/.local/bin/gcc && \
    ln -s /usr/bin/ccache /root/.local/bin/g++ && \
    ln -s /usr/bin/ccache /root/.local/bin/cc && \
    ln -s /usr/bin/ccache /root/.local/bin/c++ && \
    ln -s /usr/bin/ccache /root/.local/bin/cc1plus

COPY ./cuda-rhel9.repo /etc/yum.repos.d/cuda-rhel9.repo
COPY ./RPM-GPG-KEY-NVIDIA-CUDA-9 /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA-CUDA-9

RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA-CUDA-9 && \
    microdnf install -y --nodocs --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        cuda-cccl-${CUDA_DASHED_VERSION} \
        cuda-command-line-tools-${CUDA_DASHED_VERSION} \
        cuda-compat-${CUDA_DASHED_VERSION} \
        cuda-compiler-${CUDA_DASHED_VERSION} \
        cuda-crt-${CUDA_DASHED_VERSION} \
        cuda-cudart-${CUDA_DASHED_VERSION} \
        cuda-cudart-devel-${CUDA_DASHED_VERSION} \
        cuda-cuobjdump-${CUDA_DASHED_VERSION} \
        cuda-cupti-${CUDA_DASHED_VERSION} \
        cuda-cuxxfilt-${CUDA_DASHED_VERSION} \
        cuda-driver-devel-${CUDA_DASHED_VERSION} \
        cuda-gdb-${CUDA_DASHED_VERSION} \
        cuda-libraries-${CUDA_DASHED_VERSION} \
        cuda-libraries-devel-${CUDA_DASHED_VERSION} \
        cuda-minimal-build-${CUDA_DASHED_VERSION} \
        cuda-nsight-compute-${CUDA_DASHED_VERSION} \
        cuda-nvcc-${CUDA_DASHED_VERSION} \
        cuda-nvdisasm-${CUDA_DASHED_VERSION} \
        cuda-nvml-devel-${CUDA_DASHED_VERSION} \
        cuda-nvprof-${CUDA_DASHED_VERSION} \
        cuda-nvprune-${CUDA_DASHED_VERSION} \
        cuda-nvrtc-${CUDA_DASHED_VERSION} \
        cuda-nvrtc-devel-${CUDA_DASHED_VERSION} \
        cuda-nvtx-${CUDA_DASHED_VERSION} \
        cuda-nvvm-${CUDA_DASHED_VERSION} \
        cuda-opencl-${CUDA_DASHED_VERSION} \
        cuda-opencl-devel-${CUDA_DASHED_VERSION} \
        cuda-profiler-api-${CUDA_DASHED_VERSION} \
        cuda-sanitizer-${CUDA_DASHED_VERSION} \
        cuda-toolkit-${CUDA_DASHED_VERSION}-config-common \
        cuda-toolkit-${CUDA_MAJOR_VERSION}-config-common \
        cuda-toolkit-config-common \
        libcublas-${CUDA_DASHED_VERSION} \
        libcublas-devel-${CUDA_DASHED_VERSION} \
        libcudnn${CUDNN_MAJOR_VERSION}-cuda-${CUDA_MAJOR_VERSION} \
        libcudnn${CUDNN_MAJOR_VERSION}-devel-cuda-${CUDA_MAJOR_VERSION} \
        libcufft-${CUDA_DASHED_VERSION} \
        libcufft-devel-${CUDA_DASHED_VERSION} \
        libcufile-${CUDA_DASHED_VERSION} \
        libcufile-devel-${CUDA_DASHED_VERSION} \
        libcurand-${CUDA_DASHED_VERSION} \
        libcurand-devel-${CUDA_DASHED_VERSION} \
        libcusolver-${CUDA_DASHED_VERSION} \
        libcusolver-devel-${CUDA_DASHED_VERSION} \
        libcusparse-${CUDA_DASHED_VERSION} \
        libcusparse-devel-${CUDA_DASHED_VERSION} \
        libnccl \
        libnccl-devel \
        libnpp-${CUDA_DASHED_VERSION} \
        libnpp-devel-${CUDA_DASHED_VERSION} \
        libnvfatbin-${CUDA_DASHED_VERSION} \
        libnvfatbin-devel-${CUDA_DASHED_VERSION} \
        libnvjitlink-${CUDA_DASHED_VERSION} \
        libnvjitlink-devel-${CUDA_DASHED_VERSION} \
        libnvjpeg-${CUDA_DASHED_VERSION} \
        libnvjpeg-devel-${CUDA_DASHED_VERSION} \
        nsight-compute-${NSIGHT_COMPUTE_VERSION} \
    && \
    microdnf clean all

ENV PATH="/usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="/usr/local/cuda/lib64/stubs"
ENV NVIDIA_CPU_ONLY=1
ENV NVIDIA_DRIVER_CAPABILITIES="compute,utility,video"
ENV NVIDIA_VISIBLE_DEVICES="all"


RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ln -s /usr/bin/ccache /root/.local/bin/nvcc && \
    ln -s /usr/bin/ccache /root/.local/bin/cicc && \
    ln -s /usr/bin/ccache /root/.local/bin/ptxas

COPY ./oneapi.repo /etc/yum.repos.d/oneapi.repo
COPY ./RPM-GPG-KEY-INTEL-SW-PRODUCTS /etc/pki/rpm-gpg/RPM-GPG-KEY-INTEL-SW-PRODUCTS

RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-INTEL-SW-PRODUCTS && \
    microdnf -y install --nodocs \
        intel-oneapi-mkl-core intel-oneapi-mkl-core-devel.x86_64 && \
    microdnf clean all

ENV INTEL_MKL_HOME="/opt/intel/oneapi/mkl/latest"

#ENV PATH="${INTEL_MKL_HOME}/bin:${PATH}"
#ENV LD_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LD_LIBRARY_PATH}"
#ENV LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LIBRARY_PATH}"
#ENV CMAKE_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${CMAKE_LIBRARY_PATH}"
#ENV C_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${C_INCLUDE_PATH}"
#ENV CPLUS_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${CPLUS_INCLUDE_PATH}"
#ENV CMAKE_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${CMAKE_INCLUDE_PATH}"

COPY --from=source /opt/hpcx /opt/hpcx
COPY --from=source /opt/pytorch /opt/pytorch
COPY --from=source /opt/tensorrt /opt/tensorrt

WORKDIR /opt/pytorch

ENV TORCH_CUDA_ARCH_LIST="Maxwell"
ENV TORCH_NVCC_FLAGS "-Xfatbin -compress-all"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source /opt/rh/gcc-toolset-${GCC_TOOLSET_VERSION}/enable && \
    source ${VIRTUAL_ENV}/bin/activate && \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install "numpy<2.0.0" packaging pyaml typing_extensions wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source /opt/rh/gcc-toolset-${GCC_TOOLSET_VERSION}/enable && \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd pytorch && \
    USE_CUPTI_SO=1 \
    USE_KINETO=1 \
    CMAKE_PREFIX_PATH="/usr/local" \
    NCCL_ROOT="/usr" \
    USE_SYSTEM_NCCL=1 \
    USE_UCC=1 \
    USE_SYSTEM_UCC=1 \
    UCC_HOME="/opt/hpcx/ucc" \
    UCC_DIR="/opt/hpcx/ucc/lib/cmake/ucc" \
    UCX_HOME="/opt/hpcx/ucx" \
    UCX_DIR="/opt/hpcx/ucx/lib/cmake/ucx" \
    CPLUS_INCLUDE_PATH="${UCC_HOME}/include:${UCX_HOME}/include:${CPLUS_INCLUDE_PATH}" \
    CFLAGS='-fno-gnu-unique' \
    DEFAULT_INTEL_MKL_DIR="${INTEL_MKL_HOME}" \
    INTEL_MKL_DIR="${INTEL_MKL_HOME}" \
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${UCC_HOME}/lib:${UCX_HOME}/lib" \
    CUDA_HOME="/usr/local/cuda" \
    PYTORCH_BUILD_VERSION=${PYTORCH_VERSION} \
    PYTORCH_BUILD_NUMBER=0 \
    ${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source /opt/rh/gcc-toolset-${GCC_TOOLSET_VERSION}/enable && \
    source ${VIRTUAL_ENV}/bin/activate && \
    ${PYTHON} -m pip install /opt/pytorch/pytorch/dist/*.whl

ENV TORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"
ENV PYTORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"
ENV PYTORCH_TENSORRTHOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"

ENV PATH="${PYTORCH_HOME}/bin:${PYTORCH_TENSORRT_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_HOME}/lib:${PYTORCH_TENSORRT_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_HOME}/lib:${PYTORCH_TENSORRT_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_HOME}/lib:${PYTORCH_TENSORRT_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_HOME}/include:${PYTTORCH_TENSORRT_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_HOME}/include:${PYTORCH_TENSORRT_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_HOME}/include:${PYTORCH_TENSORRT_HOME}/include:${CMAKE_INCLUDE_PATH}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_AUDIO_VERSION} https://github.com/pytorch/audio.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source /opt/rh/gcc-toolset-${GCC_TOOLSET_VERSION}/enable && \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd audio && \
    USE_CUPTI_SO=1 \
    USE_KINETO=1 \
    CMAKE_PREFIX_PATH="/usr/local" \
    NCCL_ROOT="/usr" \
    USE_SYSTEM_NCCL=1 \
    USE_UCC=1 \
    USE_SYSTEM_UCC=1 \
    UCC_HOME="/opt/hpcx/ucc" \
    UCC_DIR="/opt/hpcx/ucc/lib/cmake/ucc" \
    UCX_HOME="/opt/hpcx/ucx" \
    UCX_DIR="/opt/hpcx/ucx/lib/cmake/ucx" \
    CPLUS_INCLUDE_PATH="${UCC_HOME}/include:${UCX_HOME}/include:${CPLUS_INCLUDE_PATH}" \
    CFLAGS='-fno-gnu-unique' \
    DEFAULT_INTEL_MKL_DIR="/usr/local" \
    INTEL_MKL_DIR="/usr/local" \
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${UCC_HOME}/lib:${UCX_HOME}/lib" \
    CUDA_HOME="/usr/local/cuda" \
    BUILD_VERSION=${PYTORCH_AUDIO_VERSION} \
    ${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source /opt/rh/gcc-toolset-${GCC_TOOLSET_VERSION}/enable && \
    source ${VIRTUAL_ENV}/bin/activate && \
    ${PYTHON} -m pip install /opt/pytorch/audio/dist/*.whl

ENV PYTORCH_AUDIO_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchaudio"

ENV PATH="${PYTORCH_AUDIO_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CMAKE_INCLUDE_PATH}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source /opt/rh/gcc-toolset-${GCC_TOOLSET_VERSION}/enable && \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd text && \
    USE_CUPTI_SO=1 \
    USE_KINETO=1 \
    CMAKE_PREFIX_PATH="/usr/local" \
    NCCL_ROOT="/usr" \
    USE_SYSTEM_NCCL=1 \
    USE_UCC=1 \
    USE_SYSTEM_UCC=1 \
    UCC_HOME="/opt/hpcx/ucc" \
    UCC_DIR="/opt/hpcx/ucc/lib/cmake/ucc" \
    UCX_HOME="/opt/hpcx/ucx" \
    UCX_DIR="/opt/hpcx/ucx/lib/cmake/ucx" \
    CPLUS_INCLUDE_PATH="${UCC_HOME}/include:${UCX_HOME}/include:${CPLUS_INCLUDE_PATH}" \
    CFLAGS='-fno-gnu-unique' \
    DEFAULT_INTEL_MKL_DIR="/usr/local" \
    INTEL_MKL_DIR="/usr/local" \
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${UCC_HOME}/lib:${UCX_HOME}/lib" \
    CUDA_HOME="/usr/local/cuda" \
    BUILD_VERSION=${PYTORCH_TEXT_VERSION} \
    ${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source /opt/rh/gcc-toolset-${GCC_TOOLSET_VERSION}/enable && \
    source ${VIRTUAL_ENV}/bin/activate && \
    ${PYTHON} -m pip install /opt/pytorch/text/dist/*.whl

ENV PYTORCH_TEXT_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchtext"

ENV PATH="${PYTORCH_TEXT_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${CMAKE_INCLUDE_PATH}"

RUN dnf install -y libjpeg-turbo-devel libpng-devel && dnf clean all

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source /opt/rh/gcc-toolset-${GCC_TOOLSET_VERSION}/enable && \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd vision && \
    USE_CUPTI_SO=1 \
    USE_KINETO=1 \
    CMAKE_PREFIX_PATH="/usr/local" \
    NCCL_ROOT="/usr" \
    USE_SYSTEM_NCCL=1 \
    USE_UCC=1 \
    USE_SYSTEM_UCC=1 \
    UCC_HOME="/opt/hpcx/ucc" \
    UCC_DIR="/opt/hpcx/ucc/lib/cmake/ucc" \
    UCX_HOME="/opt/hpcx/ucx" \
    UCX_DIR="/opt/hpcx/ucx/lib/cmake/ucx" \
    CPLUS_INCLUDE_PATH="${UCC_HOME}/include:${UCX_HOME}/include:${CPLUS_INCLUDE_PATH}" \
    CFLAGS='-fno-gnu-unique' \
    DEFAULT_INTEL_MKL_DIR="/usr/local" \
    INTEL_MKL_DIR="/usr/local" \
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${UCC_HOME}/lib:${UCX_HOME}/lib" \
    CUDA_HOME="/usr/local/cuda" \
    BUILD_VERSION=${PYTORCH_VISION_VERSION} \
    ${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source /opt/rh/gcc-toolset-${GCC_TOOLSET_VERSION}/enable && \
    source ${VIRTUAL_ENV}/bin/activate && \
    ${PYTHON} -m pip install /opt/pytorch/vision/dist/*.whl

ENV PYTORCH_VISION_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchvision"

ENV PATH="${PYTORCH_VISION_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_VISION_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_VISION_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_VISION_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_VISION_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_VISION_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_VISION_HOME}/include:${CMAKE_INCLUDE_PATH}"

COPY --from=source /opt/nvidia/nvidia_entrypoint.sh /opt/nvidia/nvidia_entrypoint.sh
COPY --from=source /opt/nvidia/entrypoint.d /opt/nvidia/entrypoint.d

WORKDIR /workspace
ENTRYPOINT ["/opt/nvidia/nvidia_entrypoint.sh"]

