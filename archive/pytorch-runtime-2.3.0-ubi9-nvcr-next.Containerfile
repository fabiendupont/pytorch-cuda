# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/pytorch-devel:2.3.0-ubi9-nvcr-next AS builder

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

ARG GCC_VERSION=13

ARG PYTORCH_VERSION=2.3.0
ARG PYTORCH_AUDIO_VERSION=2.3.0
ARG PYTORCH_TENSORRT_VERSION=2.3.0
ARG PYTORCH_TEXT_VERSION=0.18.0
ARG PYTORCH_VISION_VERSION=0.18.1
ENV NVIDIA_DALI_VERSION=1.38.0
ARG NVIDIA_FUSER_VERSION=0.0.13

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
        gnupg2 \
        jq \
        libjpeg-turbo \
        libpng \
        libstdc++ \
        libtiff \
        libtool \
        libuuid \
        libxslt \
        libyaml \
        make \
        ncurses \
        ninja-build \
        pango \
        ${PYTHON} \
        ${PYTHON}-pybind11 \
        ${PYTHON}-pip \
        sudo \
        tk \
        unzip \
        valgrind \
        vim \
        wget \
        which \
    && \
    microdnf clean all && \
    ${PYTHON} -m venv ${VIRTUAL_ENV}

RUN microdnf install -y --nodocs --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        gdbm \
        libsndfile \
        lmdb \
        protobuf-compiler \
        protobuf-c \
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
    microdnf clean all && \
    mkdir -p /root/.cache/ccache && \
    mkdir -p /root/.local/bin

ENV PATH=/root/.local/bin:${PATH}

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
        cuda-cuobjdump-${CUDA_DASHED_VERSION} \
        cuda-cupti-${CUDA_DASHED_VERSION} \
        cuda-cuxxfilt-${CUDA_DASHED_VERSION} \
        cuda-driver-devel-${CUDA_DASHED_VERSION} \
        cuda-gdb-${CUDA_DASHED_VERSION} \
        cuda-libraries-${CUDA_DASHED_VERSION} \
        cuda-minimal-build-${CUDA_DASHED_VERSION} \
        cuda-nsight-compute-${CUDA_DASHED_VERSION} \
        cuda-nvcc-${CUDA_DASHED_VERSION} \
        cuda-nvdisasm-${CUDA_DASHED_VERSION} \
        cuda-nvml-devel-${CUDA_DASHED_VERSION} \
        cuda-nvprof-${CUDA_DASHED_VERSION} \
        cuda-nvprune-${CUDA_DASHED_VERSION} \
        cuda-nvrtc-${CUDA_DASHED_VERSION} \
        cuda-nvtx-${CUDA_DASHED_VERSION} \
        cuda-nvvm-${CUDA_DASHED_VERSION} \
        cuda-opencl-${CUDA_DASHED_VERSION} \
        cuda-profiler-api-${CUDA_DASHED_VERSION} \
        cuda-sanitizer-${CUDA_DASHED_VERSION} \
        cuda-toolkit-${CUDA_DASHED_VERSION}-config-common \
        cuda-toolkit-${CUDA_MAJOR_VERSION}-config-common \
        cuda-toolkit-config-common \
        libcublas-${CUDA_DASHED_VERSION} \
        libcudnn${CUDNN_MAJOR_VERSION}-cuda-${CUDA_MAJOR_VERSION} \
        libcufft-${CUDA_DASHED_VERSION} \
        libcufile-${CUDA_DASHED_VERSION} \
        libcurand-${CUDA_DASHED_VERSION} \
        libcusolver-${CUDA_DASHED_VERSION} \
        libcusparse-${CUDA_DASHED_VERSION} \
        libnccl \
        libnpp-${CUDA_DASHED_VERSION} \
        libnvfatbin-${CUDA_DASHED_VERSION} \
        libnvjitlink-${CUDA_DASHED_VERSION} \
        libnvjpeg-${CUDA_DASHED_VERSION} \
        nsight-compute-${NSIGHT_COMPUTE_VERSION} \
    && \
    microdnf clean all

ENV CUDA_HOME="/usr/local/cuda"
ENV LIBRARY_PATH="/usr/local/cuda/lib64/stubs"
ENV NVIDIA_CPU_ONLY=1
ENV NVIDIA_DRIVER_CAPABILITIES="compute,utility,video"
ENV NVIDIA_VISIBLE_DEVICES="all"
ENV TORCH_CUDA_ARCH_LIST="7.0 7.2 7.5 8.0 8.6 8.7 8.9 9.0"

ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${CUDA_HOME}/lib64/stubs:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${CUDA_HOME}/lib64:${CUDAHOME}/lib64/stubs:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${CUDA_HOME}/lib64:${CUDA_HOME}/lib64/stubs:${CMAKE_LIBRARY_PATH}"
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
        intel-oneapi-mkl-core && \
    microdnf clean all

ENV INTEL_MKL_HOME="/opt/intel/oneapi/mkl/latest"

ENV PATH="${INTEL_MKL_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${CMAKE_INCLUDE_PATH}"

COPY --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}

ENV TORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"
ENV PYTORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"

ENV PATH="${PYTORCH_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_HOME}/include:${CMAKE_INCLUDE_PATH}"



COPY --from=builder /opt/tensorrt /opt/tensorrt

ENV PATH="/opt/tensorrt/bin:${PATH}"

WORKDIR /workspace

ENTRYPOINT ["/usr/bin/bash"]
