# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4

ARG NVIDIA_SOURCE_IMAGE_REPOSITORY=nvcr.io/nvidia
ARG NVIDIA_SOURCE_IMAGE_NAME=pytorch
ARG NVIDIA_SOURCE_IMAGE_TAG=24.04-py3

ARG RHEL_MINOR_VERSION=9.4
ARG RHEL_MAJOR_VERSION=9
ARG CUDA_VERSION=12.4.1

FROM ${NVIDIA_SOURCE_IMAGE_REPOSITORY}/${NVIDIA_SOURCE_IMAGE_NAME}:${NVIDIA_SOURCE_IMAGE_TAG} AS source

FROM registry.redhat.io/ubi9/ubi-minimal:${RHEL_MINOR_VERSION}

ARG RHEL_MAJOR_VERSION=9

ENV LD_LIBRARY_PATH=/usr/lib64:/usr/lib

ARG CUDA_VERSION=12.4.1
ARG CUDA_DASHED_VERSION=12-4
ARG CUDA_MAJOR_VERSION=12
ARG CUDA_MINOR_VERSION=12.4
ARG CUDNN_MAJOR_VERSION=9

ARG PYTHON_VERSION=3.11
ENV PYTHON=python${PYTHON_VERSION}
ENV VIRTUAL_ENV=/opt/${PYTHON}/venv
ARG PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PYTHONIOENCODING=utf-8

ARG PYTORCH_VERSION=2.3.0
ARG PYTORCH_AUDIO_VERSION=2.3.0
ARG PYTORCH_TENSORRT_VERSION=2.3.0
ARG PYTORCH_TEXT_VERSION=0.18.0
ARG PYTORCH_VISION_VERSION=0.18.1

ENV NVIDIA_PRODUCT_NAME=PyTorch
# Taints the wheel version
#ENV NVIDIA_PYTORCH_VERSION=24.04

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
        gcc \
        gcc-c++ \
        gcc-gfortran \
        gdb \
        git-core \
        glibc-devel \
        glibc-headers \
        gnupg2 \
        jq \
        libffi-devel \
        libjpeg-turbo-devel \
        libpng-devel \
        librdmacm \
        libstdc++-devel \
        libtiff \
        libtiff-devel \
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
        cuda-compat-${CUDA_DASHED_VERSION} \
        cuda-minimal-build-${CUDA_DASHED_VERSION} \
        cuda-toolkit-${CUDA_DASHED_VERSION} \
        libcudnn${CUDNN_MAJOR_VERSION}-cuda-${CUDA_MAJOR_VERSION} \
        libcudnn${CUDNN_MAJOR_VERSION}-devel-cuda-${CUDA_MAJOR_VERSION} \
        libnccl \
        libnccl-devel \
        libcutensor2 \
        libcutensor-devel \
        tensorrt-devel \
    && \
    microdnf clean all && \
    ln -s lubcuda.so.1 /usr/lib64/libcuda.so

ENV _CUDA_COMPAT_PATH=/usr/local/cuda/compat
ENV CUDA_CACHE_DISABLE=1
ENV CUDA_HOME="/usr/local/cuda"
ENV CUDA_MODULE_LOADING="LAZY"
ENV CUDA_VERSION=${CUDA_VERSION}
ENV LIBRARY_PATH="/usr/local/cuda/lib64/stubs"
ENV NCCL_WORK_FIFO_DEPTH=4194304
ENV NUMBA_CUDA_DRIVER="/usr/lib64/libcuda.so.1"
ENV NVIDIA_CPU_ONLY=1
ENV NVIDIA_DRIVER_CAPABILITIES="compute,utility,video"
ENV NVIDIA_REQUIRE_CUDA=cuda>=9.0
ENV NVIDIA_REQUIRE_JETPACK_HOST_MOUNTS=""
ENV NVIDIA_VISIBLE_DEVICES="all"

ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/compat:${CUDA_HOME}/lib64:${CUDA_HOME}/lib64/stubs:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${CUDA_HOME}/compat:${CUDA_HOME}/lib64:${CUDA_HOME}/lib64/stubs:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${CUDA_HOME}/compat:${CUDA_HOME}/lib64:${CUDA_HOME}/lib64/stubs:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${CUDA_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${CUDA_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${CUDA_HOME}/include:${CMAKE_INCLUDE_PATH}"

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

ENV PATH="${INTEL_MKL_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${CMAKE_INCLUDE_PATH}"

COPY --from=source /opt/hpcx /opt/hpcx

ENV PATH="/opt/hpcx/clusterkit/bin:/opt/hpcx/hcoll/bin:/opt/hpcx/ompi/bin:/opt/hpcx/sharp/bin:/opt/hpcx/sharp/sbin:/opt/hpcx/ucc/bin:/opt/hpcx/ucx/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/hpcx/clusterkit/lib:/opt/hpcx/hcoll/lib:/opt/hpcx/nccl_rdma_sharp_plugin/lib:/opt/hpcx/ompi/lib:/opt/hpcx/sharp/lib:/opt/hpcx/ucc/lib:/opt/hpcx/ucx/lib:${LD_LIBRARY_PATH}"
ENV OMPI_MCA_coll_hcoll_enable=0
ENV OPAL_PREFIX="/opt/hpcx/ompi"
ENV UCC_CL_BASIC_TLS="^sharp"

COPY --from=source /opt/pytorch /opt/pytorch

COPY --from=source /opt/tensorrt /opt/tensorrt

ENV PATH="/opt/tensorrt/bin:${PATH}"

COPY --from=source /opt/nvidia/nvidia_entrypoint.sh /opt/nvidia/nvidia_entrypoint.sh
COPY --from=source /opt/nvidia/entrypoint.d /opt/nvidia/entrypoint.d

RUN echo "source \${VIRTUAL_ENV}/bin/activate" >> /opt/nvidia/entrypoint.d/00-python-venv.sh && \
    echo "export PS1=[\h@pytorch${PYTORCH_VERSION} \W]\$ " >> /opt/nvidia/entrypoint.d/00-python-venv.sh

RUN echo "export CUBLAS_VERSION=$(rpm -q --qf '%{VERSION}' libcublas-${CUDA_DASHED_VERSION})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export CUDA_DRIVER_VERSION=$(rpm -q --qf '%{VERSION}' cuda-compat-${CUDA_DASHED_VERSION})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export CUDNN_VERSION=$(rpm -q --qf '%{VERSION}' libcudnn${CUDNN_MAJOR_VERSION}-cuda-${CUDA_MAJOR_VERSION})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export CUFFT_VERSION=$(rpm -q --qf '%{VERSION}' libcufft-${CUDA_DASHED_VERSION})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export CURAND_VERSION=$(rpm -q --qf '%{VERSION}' libcurand-${CUDA_DASHED_VERSION})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export CUSOLVER_VERSION=$(rpm -q --qf '%{VERSION}' libcusolver-${CUDA_DASHED_VERSION})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export CUSPARSE_VERSION=$(rpm -q --qf '%{VERSION}' libcusparse-${CUDA_DASHED_VERSION})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export CUTENSOR_VERSION=$(rpm -q --qf '%{VERSION}' libcutensor2)" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export HPCX_VERSION=$(grep "^HPC-X v" /opt/hpcx/VERSION | sed 's/HPC-X v//')" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export NCCL_VERSION=$(rpm -q --qf '%{VERSION}' libnccl)" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export NPP_VERSION=$(rpm -q --qf '%{VERSION}' libnpp-${CUDA_DASHED_VERSION})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    export NSIGHT_COMPUTE_PKG="nsight-compute-$(ls -1 /opt/nvidia/nsight-compute)" && \
    echo "export NSIGHT_COMPUTE_VERSION=$(rpm -q --qf '%{VERSION}' ${NSIGHT_COMPUTE_PKG})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    export NSIGHT_SYSTEMS_PKG="nsight-systems-$(ls -1 /opt/nvidia/nsight-compute)" && \
    echo "export NSIGHT_SYSTEMS_VERSION=$(rpm -q --qf '%{VERSION}' ${NSIGHT_SYSTEMS_PKG})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export NVJPEG_VERSION=$(rpm -q --qf '%{VERSION}' libnvjpeg-${CUDA_DASHED_VERSION})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export OPENMPI_VERSION=$(${OPAL_PREFIX}/bin/ompi_info | grep "Open MPI:" | awk '{ print $3; }')" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export OPENUCX_VERSION=$(/opt/hpcx/ucx/bin/ucx_info -v | grep '# Library version: ' | awk '{ print $4; }')" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export RDMACORE_VERSION=$(rpm -q --qf '%{VERSION}' librdmacm)" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export TRT_VERSION=$(rpm -q --qf '%{VERSION}' tensorrt-devel)" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh


ENV COCOAPI_VERSION=2.0.8
ENV DALI_VERSION=1.36.0
#ENV GDRCOPY_VERSION=
#ENV NVFUSER_VERSION=
#ENV POLYGRAPHY_VERSION=
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install --no-deps \
        nvidia-dali-cuda120==${DALI_VERSION} \
        "pycocotools==${COCOAPI_VERSION}"

# --- NVIDIA Extra Libraries --- #

# --- NVIDIA DALI --- #
# The wheel is available, but we build from source
# Source code: https://github.com/NVIDIA/DALI.git
# License: Apache 2.0
#
# Issues:
# - Depends on libtar.a, which is not available in RHEL 9

#WORKDIR /opt/nvidia
#
#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    git clone --depth 1 -b v${NVIDIA_DALI_VERSION} https://github.com/NVIDIA/DALI.git && \
#    cd DALI && \
#    git submodule sync && \
#    git submodule update --init --recursive
#
#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    source ${VIRTUAL_ENV}/bin/activate && \
#    cd DALI && \
#    mkdir build && \
#    cd build && \
#    cmake -D CMAKE_BUILD_TYPE=Release .. && \
#    make -j"$(nproc)" && \
#    ls && exit 1

WORKDIR /opt/pytorch

ENV TORCH_CUDA_ARCH_LIST="5.2 6.0 6.1 7.0 7.2 7.5 8.0 8.6 8.7 9.0+PTX"
ENV TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1
ENV TORCH_CUDNN_V8_API_ENABLED=1
ENV USE_EXPERIMENTAL_CUDNN_V8_API=1

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install "numpy<2.0.0" packaging pyaml typing_extensions wheel

ENV PYTORCH_BUILD_VERSION=${PYTORCH_VERSION}
ENV PYTORCH_BUILD_NUMBER=0

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
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
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${UCC_HOME}/lib:${UCX_HOME}/lib" \
    CFLAGS='-fno-gnu-unique' \
    DEFAULT_INTEL_MKL_DIR="${INTEL_MKL_HOME}" \
    INTEL_MKL_DIR="${INTEL_MKL_HOME}" \
    NCCL_INCLUDE_DIR="/usr/include" \
    TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    python setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /opt/pytorch/pytorch/dist/*.whl

ENV TORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"
ENV PYTORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"

ENV PATH="${PYTORCH_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_HOME}/include:${CMAKE_INCLUDE_PATH}"

# --- PyTorch - TensorRT --- #
#

# There is a dependency on Bazel, which is not available for RHEL 9

#ARG BAZEL_VERSION=7.2.0
#
#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    curl -sL -o ${HOME}/.local/bin/bazel https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-linux-x86_64 && \
#    chmod u+x /root/.local/bin/bazel && \
#    source ${VIRTUAL_ENV}/bin/activate && \
#    cd torch_tensorrt && \
#    USE_CUPTI_SO=1 \
#    USE_KINETO=1 \
#    CMAKE_PREFIX_PATH="/usr/local" \
#    NCCL_ROOT="/usr" \
#    USE_SYSTEM_NCCL=1 \
#    USE_UCC=1 \
#    USE_SYSTEM_UCC=1 \
#    UCC_HOME="/opt/hpcx/ucc" \
#    UCC_DIR="/opt/hpcx/ucc/lib/cmake/ucc" \
#    UCX_HOME="/opt/hpcx/ucx" \
#    UCX_DIR="/opt/hpcx/ucx/lib/cmake/ucx" \
#    CPLUS_INCLUDE_PATH="${UCC_HOME}/include:${UCX_HOME}/include:${CPLUS_INCLUDE_PATH}" \
#    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${UCC_HOME}/lib:${UCX_HOME}/lib" \
#    CFLAGS='-fno-gnu-unique' \
#    DEFAULT_INTEL_MKL_DIR="/usr/local" \
#    INTEL_MKL_DIR="/usr/local" \
#    TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
#    BUILD_VERSION=${PYTORCH_TENSORRT_VERSION} \
#    RELEASE=1 \
#    python setup.py bdist_wheel && \
#    python -m pip install /opt/pytorch/torch_tensorrt/dist/*.whl

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    source ${VIRTUAL_ENV}/bin/activate && \
#    cd torch_tensorrt && \
#    BUILD_VERSION=${PYTORCH_TENSORRT_VERSION} \
#    PYTORCH_VERSION="${PYTORCH_VERSION}.nv${NVIDIA_PYTORCH_VERSION}" \
#    python setup.py bdist_wheel --fx-only

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    source ${VIRTUAL_ENV}/bin/activate && \
#    python -m pip install /opt/pytorch/torch_tensorrt/dist/*.whl

#ENV PYTORCH_TENSORRT_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch_tensorrt"

#ENV PATH="${PYTORCH_TENSORRT_HOME}/bin:${PATH}"
#ENV LD_LIBRARY_PATH="${PYTORCH_TENSORRT_HOME}/lib:${LD_LIBRARY_PATH}"
#ENV LIBRARY_PATH="${PYTORCH_TENSORRT_HOME}/lib:${LIBRARY_PATH}"
#ENV CMAKE_LIBRARY_PATH="${PYTORCH_TENSORRT_HOME}/lib:${CMAKE_LIBRARY_PATH}"
#ENV C_INCLUDE_PATH="${PYTORCH_TENSORRT_HOME}/include:${C_INCLUDE_PATH}"
#ENV CPLUS_INCLUDE_PATH="${PYTORCH_TENSORRT_HOME}/include:${CPLUS_INCLUDE_PATH}"
#ENV CMAKE_INCLUDE_PATH="${PYTORCH_TENSORRT_HOME}/include:${CMAKE_INCLUDE_PATH}"

# --- Triton --- #

ARG TRITON_VERSION=2.3.0

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install "triton==${TRITON_VERSION}"

# --- PyTorch - Torch Audio --- #
# We install from the Github repository, as the code is not part of NVIDIA image

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_AUDIO_VERSION} https://github.com/pytorch/audio.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
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
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${UCC_HOME}/lib:${UCX_HOME}/lib" \
    CFLAGS='-fno-gnu-unique' \
    DEFAULT_INTEL_MKL_DIR="/usr/local" \
    INTEL_MKL_DIR="/usr/local" \
    TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    BUILD_VERSION=${PYTORCH_AUDIO_VERSION} \
    USE_CUDNN=1 \
    BUILD_SOX=0 \
    python setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /opt/pytorch/audio/dist/*.whl

ENV PYTORCH_AUDIO_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchaudio"

ENV PATH="${PYTORCH_AUDIO_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CMAKE_INCLUDE_PATH}"

# --- PyTorch - Torch Data --- #

ENV PYTORCH_DATA_VERSION=0.7.1

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd data && \
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
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${UCC_HOME}/lib:${UCX_HOME}/lib" \
    CFLAGS='-fno-gnu-unique' \
    DEFAULT_INTEL_MKL_DIR="/usr/local" \
    INTEL_MKL_DIR="/usr/local" \
    TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    BUILD_VERSION=${PYTORCH_DATA_VERSION} \
    python setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /opt/pytorch/data/dist/*.whl

ENV PYTORCH_DATA_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchdata"

ENV PATH="${PYTORCH_DATA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_DATA_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_DATA_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_DATA_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_DATA_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_DATA_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_DATA_HOME}/include:${CMAKE_INCLUDE_PATH}"

# --- PyTorch - Torch Text --- #

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
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
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${UCC_HOME}/lib:${UCX_HOME}/lib" \
    CFLAGS='-fno-gnu-unique' \
    DEFAULT_INTEL_MKL_DIR="/usr/local" \
    INTEL_MKL_DIR="/usr/local" \
    TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    BUILD_VERSION=${PYTORCH_TEXT_VERSION} \
    python setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /opt/pytorch/text/dist/*.whl

ENV PYTORCH_TEXT_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchtext"

ENV PATH="${PYTORCH_TEXT_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${CMAKE_INCLUDE_PATH}"

# --- PyTorch - Torch Vision --- #

#ENV C_INCLUDE_PATH="/usr/include/ffmpeg/libavcode:/usr/include/ffmpeg/libavdevice:/usr/include/ffmpeg:${C_INCLUDE_PATH}"
#ENV CPLUS_INCLUDE_PATH="/usr/include/ffmpeg:${CPLUS_INCLUDE_PATH}"
#ENV CMAKE_INCLUDE_PATH="/usr/include/ffmpeg:${CMAKE_INCLUDE_PATH}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
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
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${UCC_HOME}/lib:${UCX_HOME}/lib" \
    CFLAGS='-fno-gnu-unique' \
    DEFAULT_INTEL_MKL_DIR="/usr/local" \
    INTEL_MKL_DIR="/usr/local" \
    TORCH_NVCC_FLAGS="-Xfatbin -compress-all" \
    TORCHVISION_INCLUDE="/usr/include/ffmpeg" \
    BUILD_VERSION=${PYTORCH_VISION_VERSION} \
    FORCE_CUDA=1 \
    python setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /opt/pytorch/vision/dist/*.whl

ENV PYTORCH_VISION_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchvision"

ENV PATH="${PYTORCH_VISION_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_VISION_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_VISION_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_VISION_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_VISION_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_VISION_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_VISION_HOME}/include:${CMAKE_INCLUDE_PATH}"

# --- NVIDIA Transformer Engine --- #
# The wheel is available, but not properly versioned. We build from source.
# Git repository: https://github.com/NVIDIA/TransformerEngine.git
# Licence: Apache 2.0

WORKDIR /opt/nvidia

ENV TRANSFORMER_ENGINE_VERSION=1.7

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${TRANSFORMER_ENGINE_VERSION} https://github.com/NVIDIA/TransformerEngine.git && \
    cd TransformerEngine && \
    git submodule sync && \
    git submodule update --init --recursive

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd TransformerEngine && \
    NVTE_FRAMEWORK=pytorch \
    BUILD_VERSION=${TRANSFORMER_ENGINE_VERSION} \
    python setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /opt/nvidia/TransformerEngine/dist/*.whl


ENV JUPYTER_PORT=8888
ENV TENSORBOARD_PORT=6006

RUN echo "export PS1=\"[\\u@pytorch${PYTORCH_VERSION} \\W]\\$ \"" >> /opt/nvidia/entrypoint.d/00-python-venv.sh

WORKDIR /workspace
ENTRYPOINT ["/opt/nvidia/nvidia_entrypoint.sh"]

