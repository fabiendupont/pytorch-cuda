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
        asciidoc \
        atlas \
        autoconf \
        automake \
        bzip2 \
        cargo \
        cmake \
        compat-openssl11 \
        docbook-dtds \
        docbook-style-xsl \
        file \
        findutils \
        git-core \
        gnupg2 \
        jq \
        libffi \
        libjpeg-turbo \
        libpng \
        librdmacm \
        libtiff \
        libtool \
        libuuid \
        libxslt \
        libyaml \
        llvm \
        ncurses \
        ninja-build \
        pango \
        pango \
        ${PYTHON} \
        ${PYTHON}-devel \
        ${PYTHON}-pip \
        readline \
        sudo \
        tk \
        unzip \
        valgrind \
        vim \
        wget \
        which \
    && \
    microdnf clean all && \
    ${PYTHON} -m venv ${VIRTUAL_ENV} && \
    cp -r /usr/include/${PYTHON}/* ${VIRTUAL_ENV}/include/${PYTHON}

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install wheel

RUN microdnf install -y --nodocs --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        gdbm \
        libsndfile \
        lmdb \
        protobuf-compiler \
        protobuf-c \
        ${PYTHON}-pybind11 \
        snappy \
    && \
    microdnf clean all
RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    microdnf install -y --nodocs --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        ffmpeg-free \
        gflags \
        glog \
        hiredis \
        jemalloc \
        lcov \
        leveldb \
        libavcodec-free \
        libavformat-free \
        libavutil-free \
        libsqlite3x \
        libswresample-free \
        libswscale-free \
        opencv \
    && \
    microdnf clean all

COPY ./cuda-rhel${RHEL_MAJOR_VERSION}.repo /etc/yum.repos.d/cuda-rhel${RHEL_MAJOR_VERSION}.repo
COPY ./RPM-GPG-KEY-NVIDIA-CUDA-${RHEL_MAJOR_VERSION} /etc/pki/rpm-gpg/RPM-GPG-KEY-NVIDIA-CUDA-${RHEL_MAJOR_VERSION}

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

COPY ./oneapi.repo /etc/yum.repos.d/oneapi.repo
COPY ./RPM-GPG-KEY-INTEL-SW-PRODUCTS /etc/pki/rpm-gpg/RPM-GPG-KEY-INTEL-SW-PRODUCTS

RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-INTEL-SW-PRODUCTS && \
    microdnf -y install --nodocs \
        intel-oneapi-mkl-core intel-oneapi-mkl-core-devel.x86_64 && \
    microdnf clean all

ENV INTEL_MKL_HOME="/opt/intel/oneapi/mkl/latest"

ENV PATH="${INTEL_MKL_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LD_LIBRARY_PATH}"

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/bash"]

