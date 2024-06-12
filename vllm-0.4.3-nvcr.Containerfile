# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/pytorch-devel:2.3.0-ubi9-nvcr

ARG PYTHON_VERSION=3.11
ENV PYTHON=python${PYTHON_VERSION}
ENV VIRTUAL_ENV=/workspace/venv

ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV PS1="(venv) ${PS1:-}"
ENV VIRTUAL_ENV_PROMPT="(venv) "

ARG TRITON_VERSION=2.1.0
ARG VLLM_VERSION=0.4.3
ARG VLLM_TGIS_ADAPTER_VERSION=0.0.4

ENV PYTHONIOENCODING=utf-8

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_REQUIRE_CUDA=cuda>=9.0

ENV CUDA_CACHE_DISABLE=1
ENV CUDA_MODULE_LOADING=LAZY
ENV NCCL_WORK_FIFO_DEPTH=4194304
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video
ENV OMPI_MCA_coll_hcoll_enable=0
ENV TENSORBOARD_PORT=6006
ENV TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1
ENV TORCH_CUDNN_V8_API_ENABLED=1
ENV USE_EXPERIMENTAL_CUDNN_V8_API=1

WORKDIR /workspace

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install packaging triton
#    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install packaging grpcio-tools mypy_protobuf

# Workaround for https://github.com/openai/triton/issues/2507 and
# https://github.com/pytorch/pytorch/issues/107960 -- hopefully
# this won't be needed for future versions of this docker image
# or future versions of triton.
RUN ldconfig /usr/local/cuda-12.4/compat/

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    git clone --depth=1 -b v${TRITON_VERSION} https://github.com/triton-lang/triton.git

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    source ${VIRTUAL_ENV}/bin/activate && \
#    cd /workspace/triton/python && \
#    export LD_LIBRARY_PATH=/opt/nvidia/nsight-compute/2024.1.1/host/target-linux-x64:${LD_LIBRARY_PATH} && \
#    MAX_JOBS=$(nproc) NVCC_THREADS=$(nproc) TRITON_BUILD_WITH_CCACHE=true ${PYTHON} setup.py bdist_wheel
##    cd /workspace/triton && \
##    MAX_JOBS=$(nproc) NVCC_THREADS=$(nproc) TRITON_BUILD_WITH_CCACHE=true pip3.11 install -e python && \
##    ls && echo "---" && ls ..

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /workspace/triton/python/dist/*.whl

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth=1 -b v${VLLM_VERSION} https://github.com/vllm-project/vllm.git && \
    cd vllm && \
    git submodule sync && \
    git submodule update --init --recursive

#ENV LD_LIBRARY_PATH="/usr/lib64:${LD_LIBRARY_PATH}"

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    microdnf install -y intel-oneapi-runtime-mkl && \
#    microdnf clean all

#ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/opt/intel/oneapi/redist/lib"

#    export CMAKE_INCLUDE_PATH="${CMAKE_INCLUDE_PATH}:/usr/include" && \
#    export CPLUS_INCLUDE_PATH="${CPLUS_INCLUDE_PATH}:/usr/include" && \
#    export C_INCLUDE_PATH="${C_INCLUDE_PATH}:/usr/include" && \

ENV VLLM_INSTALL_PUNICA_KERNELS=1

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/vllm && \
    MAX_JOBS=$(nproc) NVCC_THREADS=$(nproc) CMAKE_BUILD_TYPE=Release CAFFE2_USE_CUDNN=1 USE_CUDNN=1 ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /workspace/vllm/dist/*.whl

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth=1 -b ${VLLM_TGIS_ADAPTER_VERSION} https://github.com/dtrifiro/vllm-tgis-adapter.git && \
    cd vllm-tgis-adapter && \
    git submodule sync && \
    git submodule update --init --recursive

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    ${PYTHON} -m pip install grpcio-tools mypy_protobuf

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/vllm-tgis-adapter && \
    PYTORCH_VERSION=$(${VIRTUAL_ENV}/bin/${PYTHON} -m pip show torch | grep 'Version:' | awk '{ print $2; }') MAX_JOBS=$(nproc) NVCC_THREADS=$(nproc) CMAKE_BUILD_TYPE=Release CAFFE2_USE_CUDNN=1 USE_CUDNN=1 ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /workspace/vllm-tgis-adapter/dist/*.whl

WORKDIR /instructlab

ENV GRPC_PORT=8033
USER 2000
ENTRYPOINT ["/workspace/venv/bin/python3", "-m", "vllm_tgis_adapter", "--distributed-executor-backend=mp"]
#ENTRYPOINT ["/workspace/venv/bin/python3.11", "-m", "vllm_tgis_adapter"]
