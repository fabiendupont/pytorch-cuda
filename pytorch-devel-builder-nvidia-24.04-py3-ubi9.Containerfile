# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4

ARG RHEL_MINOR_VERSION=9.4

FROM registry.redhat.io/ubi9/ubi-minimal:${RHEL_MINOR_VERSION}

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
        llvm \
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

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install wheel

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

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/bash"]
