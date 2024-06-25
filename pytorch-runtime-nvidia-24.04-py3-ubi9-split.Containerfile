# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4

ARG NVIDIA_SOURCE_IMAGE_REPOSITORY=nvcr.io/nvidia
ARG NVIDIA_SOURCE_IMAGE_NAME=pytorch
ARG NVIDIA_SOURCE_IMAGE_TAG=24.04-py3

ARG RHEL_MINOR_VERSION=9.4
ARG RHEL_MAJOR_VERSION=9
ARG CUDA_VERSION=12.4.1

FROM ${NVIDIA_SOURCE_IMAGE_REPOSITORY}/${NVIDIA_SOURCE_IMAGE_NAME}:${NVIDIA_SOURCE_IMAGE_TAG} AS source

FROM quay.io/fabiendupont/pytorch-devel-builder:nvidia-${NVIDIA_SOURCE_IMAGE_TAG}-ubi${RHEL_MAJOR_VERSION} AS builder

COPY --from=source /opt/pytorch /opt/pytorch

WORKDIR /opt/pytorch

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

# --- PyTorch - Torch --- #

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    git clone --depth=1 -b ${NVIDIA_SOURCE_IMAGE_NAME}-${NVIDIA_SOURCE_IMAGE_TAG} git@gitlab.com:smgglrs/rhel-ai/pytorch/nvidia/pytorch.git

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


# Workaround for https://github.com/openai/triton/issues/2507 and
# https://github.com/pytorch/pytorch/issues/107960 -- hopefully
# this won't be needed for future versions of this docker image
# or future versions of triton.
#RUN ldconfig /usr/local/cuda-12.4/compat/

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    git clone --depth=1 -b v${TRITON_VERSION} https://github.com/triton-lang/triton.git
#    git submodule sync
#    git submodule update --init --recursive

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    source ${VIRTUAL_ENV}/bin/activate && \
#    cd /workspace/triton/python && \
#    export LD_LIBRARY_PATH=/opt/nvidia/nsight-compute/2024.1.1/host/target-linux-x64:${LD_LIBRARY_PATH} && \
#    MAX_JOBS=$(nproc) NVCC_THREADS=$(nproc) TRITON_BUILD_WITH_CCACHE=true ${PYTHON} setup.py bdist_wheel

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    source ${VIRTUAL_ENV}/bin/activate && \
#    python -m pip install /opt/pytorch/triton/dist/*.whl

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
    MAX_JOBS=$(nproc) python setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /opt/nvidia/TransformerEngine/dist/*.whl

# --- NVIDIA Fuser --- #

#WORKDIR /opt/nvidia

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    git clone --depth 1 https://github.com/NVIDIA/Fuser && \
#    cd Fuser && \
#    git submodule sync && \
#    git submodule update --init --recursive

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    source ${VIRTUAL_ENV}/bin/activate && \
#    cd Fuser && \
#    BUILD_WITH_UCC=True 

# --- NVIDIA Apex --- #

#WORKDIR /opt/pytorch

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    source ${VIRTUAL_ENV}/bin/activate && \
#    cd apex && \
#    python setup.py bdist_wheel --cpp_ext --cuda_ext --cudnn_gbn --nccl_p2p

FROM quay.io/fabiendupont/pytorch-runtime-builder:nvidia-${NVIDIA_SOURCE_IMAGE_TAG}-ubi${RHEL_MAJOR_VERSION}

ARG CUDA_VERSION=12.4.1
ARG CUDA_DASHED_VERSION=12-4
ARG CUDA_MAJOR_VERSION=12
ARG CUDNN_MAJOR_VERSION=9

COPY --from=source /opt/hpcx /opt/hpcx

ENV PATH="/opt/hpcx/clusterkit/bin:/opt/hpcx/hcoll/bin:/opt/hpcx/ompi/bin:/opt/hpcx/sharp/bin:/opt/hpcx/sharp/sbin:/opt/hpcx/ucc/bin:/opt/hpcx/ucx/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/hpcx/clusterkit/lib:/opt/hpcx/hcoll/lib:/opt/hpcx/nccl_rdma_sharp_plugin/lib:/opt/hpcx/ompi/lib:/opt/hpcx/sharp/lib:/opt/hpcx/ucc/lib:/opt/hpcx/ucx/lib:${LD_LIBRARY_PATH}"
ENV OMPI_MCA_coll_hcoll_enable=0
ENV OPAL_PREFIX="/opt/hpcx/ompi"
ENV UCC_CL_BASIC_TLS="^sharp"

COPY --from=builder /opt/pytorch/pytorch/dist/*.whl /tmp/wheels/
COPY --from=builder /opt/pytorch/audio/dist/*.whl /tmp/wheels/
COPY --from=builder /opt/pytorch/data/dist/*.whl /tmp/wheels/
COPY --from=builder /opt/pytorch/text/dist/*.whl /tmp/wheels/
COPY --from=builder /opt/pytorch/vision/dist/*.whl /tmp/wheels/
COPY --from=builder /opt/nvidia/TransformerEngine/dist/*.whl /tmp/wheels

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /tmp/wheels/*.whl && \
    find ${VIRTUAL_ENV} -name __pycache__ | xargs rm -rf && \
    rm -rf /tmp/wheels

ENV TORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"
ENV PYTORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"

ENV PATH="${PYTORCH_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_HOME}/include:${CMAKE_INCLUDE_PATH}"

ENV PYTORCH_AUDIO_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchaudio"

ENV PATH="${PYTORCH_AUDIO_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CMAKE_INCLUDE_PATH}"

ENV PYTORCH_DATA_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchdata"

ENV PATH="${PYTORCH_DATA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_DATA_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_DATA_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_DATA_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_DATA_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_DATA_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_DATA_HOME}/include:${CMAKE_INCLUDE_PATH}"

ENV PYTORCH_TEXT_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchtext"

ENV PATH="${PYTORCH_TEXT_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_TEXT_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_TEXT_HOME}/include:${CMAKE_INCLUDE_PATH}"

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

