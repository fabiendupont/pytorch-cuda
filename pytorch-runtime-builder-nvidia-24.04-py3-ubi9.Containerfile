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
ARG NSIGHT_COMPUTE_VERSION=2024.1.1
ARG NSIGHT_SYSTEMS_VERSION=2024.2.3

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
        cuda-cccl-${CUDA_DASHED_VERSION} \
        cuda-command-line-tools-${CUDA_DASHED_VERSION} \
        cuda-compat-${CUDA_DASHED_VERSION} \
        cuda-compiler-${CUDA_DASHED_VERSION} \
        cuda-crt-${CUDA_DASHED_VERSION} \
        cuda-cudart-${CUDA_DASHED_VERSION} \
        cuda-cuobjdump-${CUDA_DASHED_VERSION} \
        cuda-cupti-${CUDA_DASHED_VERSION} \
        cuda-cuxxfilt-${CUDA_DASHED_VERSION} \
        cuda-documentation-${CUDA_DASHED_VERSION} \
        cuda-gdb-${CUDA_DASHED_VERSION} \
        cuda-libraries-${CUDA_DASHED_VERSION} \
        cuda-minimal-build-${CUDA_DASHED_VERSION} \
        cuda-nsight-${CUDA_DASHED_VERSION} \
        cuda-nsight-compute-${CUDA_DASHED_VERSION} \
        cuda-nsight-systems-${CUDA_DASHED_VERSION} \
        cuda-nvcc-${CUDA_DASHED_VERSION} \
        cuda-nvdisasm-${CUDA_DASHED_VERSION} \
        cuda-nvprof-${CUDA_DASHED_VERSION} \
        cuda-nvprune-${CUDA_DASHED_VERSION} \
        cuda-nvrtc-${CUDA_DASHED_VERSION} \
        cuda-nvtx-${CUDA_DASHED_VERSION} \
        cuda-nvvm-${CUDA_DASHED_VERSION} \
        cuda-nvvp-${CUDA_DASHED_VERSION} \
        cuda-opencl-${CUDA_DASHED_VERSION} \
        cuda-profiler-api-${CUDA_DASHED_VERSION} \
        cuda-sanitizer-${CUDA_DASHED_VERSION} \
        cuda-toolkit-${CUDA_DASHED_VERSION}-config-common \
        cuda-toolkit-${CUDA_MAJOR_VERSION}-config-common \
        cuda-toolkit-config-common \
        gds-tools-${CUDA_DASHED_VERSION} \
        libcublas-${CUDA_DASHED_VERSION} \
        libcudnn${CUDNN_MAJOR_VERSION}-cuda-${CUDA_MAJOR_VERSION} \
        libcufft-${CUDA_DASHED_VERSION} \
        libcufile-${CUDA_DASHED_VERSION} \
        libcurand-${CUDA_DASHED_VERSION} \
        libcusolver-${CUDA_DASHED_VERSION} \
        libcusparse-${CUDA_DASHED_VERSION} \
        libcutensor2 \
        libnccl \
        libnpp-${CUDA_DASHED_VERSION} \
        libnvfatbin-${CUDA_DASHED_VERSION} \
        libnvinfer-bin \
        libnvinfer-dispatch10 \
        libnvinfer-lean10 \
        libnvinfer-plugin10 \
        libnvinfer-vc-plugin10 \
        libnvinfer10 \
        libnvjitlink-${CUDA_DASHED_VERSION} \
        libnvjpeg-${CUDA_DASHED_VERSION} \
        libnvonnxparsers10 \
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

COPY ./oneapi.repo /etc/yum.repos.d/oneapi.repo
COPY ./RPM-GPG-KEY-INTEL-SW-PRODUCTS /etc/pki/rpm-gpg/RPM-GPG-KEY-INTEL-SW-PRODUCTS

RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-INTEL-SW-PRODUCTS && \
    microdnf -y install --nodocs \
        intel-oneapi-mkl-core intel-oneapi-mkl-core-devel.x86_64 && \
    microdnf clean all

ENV INTEL_MKL_HOME="/opt/intel/oneapi/mkl/latest"

ENV PATH="${INTEL_MKL_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LD_LIBRARY_PATH}"

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

