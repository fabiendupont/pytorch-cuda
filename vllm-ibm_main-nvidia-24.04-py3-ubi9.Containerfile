# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/pytorch-devel:nvidia-24.04-py3-ubi9

ARG PYTHON_VERSION=3.11
ENV PYTHON=python${PYTHON_VERSION}
ARG PIP_DISABLE_PIP_VERSION_CHECK=1

ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

#ARG TRITON_VERSION=2.1.0
ARG XFORMERS_VERSION=0.0.26.post1
#ARG VLLM_VERSION=0.5.0.post1
ARG VLLM_VERSION=main
ARG VLLM_FLASH_ATTN_VERSION=2.5.9
ARG VLLM_TGIS_ADAPTER_VERSION=0.0.4

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install packaging grpcio-tools mypy_protobuf

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth=1 -b v${XFORMERS_VERSION} https://github.com/facebookresearch/xformers.git && \
    cd xformers && \
    git submodule sync && \
    git submodule update --init --recursive

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/xformers && \
    export LD_LIBRARY_PATH=/opt/nvidia/nsight-compute/2024.1.1/host/target-linux-x64:${LD_LIBRARY_PATH} && \
    MAX_JOBS=16 NVCC_THREADS=8 XFORMERS_BUILD_TYPE=release BUILD_VERSION=${XFORMERS_VERSION} python setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /workspace/xformers/dist/*.whl

#    git clone --depth=1 -b v${VLLM_VERSION} https://github.com/vllm-project/vllm.git && \
RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth=1 -b ${VLLM_VERSION} https://github.com/opendatahub-io/vllm.git && \
    cd vllm && \
    git submodule sync && \
    git submodule update --init --recursive

ENV VLLM_INSTALL_PUNICA_KERNELS=1

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/vllm && \
    MAX_JOBS=$(nproc) NVCC_THREADS=$(nproc) CMAKE_BUILD_TYPE=Release CAFFE2_USE_CUDNN=1 USE_CUDNN=1 python setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /workspace/vllm/dist/*.whl

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth=1 -b v${VLLM_FLASH_ATTN_VERSION} https://github.com/vllm-project/flash-attention.git && \
    cd vllm && \
    git submodule sync && \
    git submodule update --init --recursive

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd vllm && \
    MAX_JOBS=$(nproc) NVCC_THREADS=$(nproc) CAFFE2_USE_CUDNN=1 USE_CUDNN=1 python setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /workspace/vllm/dist/*.whl



RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth=1 -b ${VLLM_TGIS_ADAPTER_VERSION} https://github.com/dtrifiro/vllm-tgis-adapter.git && \
    cd vllm-tgis-adapter && \
    git submodule sync && \
    git submodule update --init --recursive

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/vllm-tgis-adapter && \
    sed -i -e '/"grpcio==.*",/s/==.*",/==1.64.1",/' -e '/"grpcio-tools==.*",/s/==.*",/==1.64.1",/' pyproject.toml && \
    PYTORCH_VERSION=${PYTORCH_BUILD_VERSION} MAX_JOBS=$(nproc) NVCC_THREADS=$(nproc) CMAKE_BUILD_TYPE=Release CAFFE2_USE_CUDNN=1 USE_CUDNN=1 python setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    python -m pip install /workspace/vllm-tgis-adapter/dist/*.whl

WORKDIR /instructlab

ENV GRPC_PORT=8033
USER 2000
ENTRYPOINT ["/opt/python3.11/venv/bin/python", "-m", "vllm_tgis_adapter", "--distributed-executor-backend=mp"]
