# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4

ARG NVIDIA_SOURCE_IMAGE_REPOSITORY=nvcr.io/nvidia
ARG NVIDIA_SOURCE_IMAGE_NAME=pytorch
ARG NVIDIA_SOURCE_IMAGE_TAG=24.04-py3

ARG RHEL_MINOR_VERSION=9.4
ARG RHEL_MAJOR_VERSION=9
ARG CUDA_VERSION=12.4.1

FROM ${NVIDIA_SOURCE_IMAGE_REPOSITORY}/${NVIDIA_SOURCE_IMAGE_NAME}:${NVIDIA_SOURCE_IMAGE_TAG} AS source

FROM registry.redhat.io/ubi9/ubi-minimal:${RHEL_MINOR_VERSION} as devel

ARG RHEL_MAJOR_VERSION=9

ENV LD_LIBRARY_PATH=/usr/lib64:/usr/lib

ARG CUDA_VERSION=12.4.1
ARG CUDA_DASHED_VERSION=12-4
ARG CUDA_MAJOR_VERSION=12
ARG CUDA_MINOR_VERSION=12.4
ARG CUDNN_MAJOR_VERSION=9

ARG PYTHON_VERSION=3.11
ENV PYTHON_VERSION=${PYTHON_VERSION}
ENV PYTHON=python${PYTHON_VERSION}
ENV VIRTUAL_ENV=/opt/${PYTHON}/venv
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PYTHONIOENCODING=utf-8

ENV PYTORCH_VERSION=2.3.0
ENV PYTORCH_AUDIO_VERSION=2.3.0
ENV PYTORCH_DATA_VERSION=0.7.1
ENV PYTORCH_TENSORRT_VERSION=2.3.0
ENV PYTORCH_TEXT_VERSION=0.18.0
ENV PYTORCH_VISION_VERSION=0.18.1

ENV PYTORCH_BUILD_VERSION=${PYTORCH_VERSION}
ENV PYTORCH_BUILD_NUMBER=0

ENV TRITON_VERSION=2.3.0
ENV TRANSFORMER_ENGINE_VERSION=1.7
ENV COCOAPI_VERSION=2.0.8
ENV DALI_VERSION=1.36.0
#ENV GDRCOPY_VERSION=
#ENV NVFUSER_VERSION=0.1.6
#ENV POLYGRAPHY_VERSION=

ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

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
        tensorrt \
        tensorrt-devel \
    && \
    microdnf clean all && \
    ln -s /usr/lib64/libcuda.so.1 /usr/lib64/libcuda.so

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

ENV TORCH_CUDA_ARCH_LIST="5.2 6.0 6.1 7.0 7.2 7.5 8.0 8.6 8.7 9.0+PTX"
ENV TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1
ENV TORCH_CUDNN_V8_API_ENABLED=1
ENV USE_EXPERIMENTAL_CUDNN_V8_API=1

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

# --- Install NVIDIA HPC-X --- #
COPY --from=source /opt/hpcx /opt/hpcx

ENV PATH="/opt/hpcx/clusterkit/bin:/opt/hpcx/hcoll/bin:/opt/hpcx/ompi/bin:/opt/hpcx/sharp/bin:/opt/hpcx/sharp/sbin:/opt/hpcx/ucc/bin:/opt/hpcx/ucx/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/hpcx/clusterkit/lib:/opt/hpcx/hcoll/lib:/opt/hpcx/nccl_rdma_sharp_plugin/lib:/opt/hpcx/ompi/lib:/opt/hpcx/sharp/lib:/opt/hpcx/ucc/lib:/opt/hpcx/ucx/lib:${LD_LIBRARY_PATH}"
ENV OMPI_MCA_coll_hcoll_enable=0
ENV OPAL_PREFIX="/opt/hpcx/ompi"
ENV UCC_CL_BASIC_TLS="^sharp"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install --no-deps \
        "numpy<2.0.0" packaging pyyaml typing_extensions wheel \
        "nvidia-dali-cuda120==${DALI_VERSION}" \
        "pycocotools==${COCOAPI_VERSION}" \
        "triton==${TRITON_VERSION}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install "triton==${TRITON_VERSION}"

COPY --from=source /opt/nvidia/nvidia_entrypoint.sh /opt/nvidia/nvidia_entrypoint.sh
COPY --from=source /opt/nvidia/entrypoint.d /opt/nvidia/entrypoint.d

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
    export NSIGHT_SYSTEMS_PKG="nsight-systems-$(ls -1 /opt/nvidia/nsight-systems)" && \
    echo "export NSIGHT_SYSTEMS_VERSION=$(rpm -q --qf '%{VERSION}' ${NSIGHT_SYSTEMS_PKG})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export NVJPEG_VERSION=$(rpm -q --qf '%{VERSION}' libnvjpeg-${CUDA_DASHED_VERSION})" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export OPENMPI_VERSION=$(${OPAL_PREFIX}/bin/ompi_info | grep "Open MPI:" | awk '{ print $3; }')" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export OPENUCX_VERSION=$(/opt/hpcx/ucx/bin/ucx_info -v | grep '# Library version: ' | awk '{ print $4; }')" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export RDMACORE_VERSION=$(rpm -q --qf '%{VERSION}' librdmacm)" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh && \
    echo "export TRT_VERSION=$(rpm -q --qf '%{VERSION}' tensorrt)" >> /opt/nvidia/entrypoint.d/80-packages-versions.sh

RUN echo "source \${VIRTUAL_ENV}/bin/activate" >> /opt/nvidia/entrypoint.d/00-python-venv.sh && \
    echo "export PS1=\"[\\u@pytorch${PYTORCH_VERSION} \\W]# \"" >> /opt/nvidia/entrypoint.d/00-python-venv.sh

WORKDIR /workspace
ENTRYPOINT ["/opt/nvidia/nvidia_entrypoint.sh"]

