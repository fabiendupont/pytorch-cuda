# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
#FROM quay.io/fabiendupont/pytorch-devel:2.3.0-ubi9-nvcr AS builder
FROM quay.io/fabiendupont/pytorch-devel:2.1.0-ubi9-nvcr

ARG PYTHON_VERSION=3.11
ENV PYTHON_VERSION=3.11
ENV PYTHON=python${PYTHON_VERSION}
ENV MAX_JOBS=$(nproc)
ENV VIRTUAL_ENV=/workspace/venv

ARG NVIDIA_DRIVER_VERSION=550.54.15
ARG NVIDIA_DRIVER_STREAM=550
ARG CUDA_VERSION=12.4
ARG CUDA_DASHED_VERSION=12-4
ARG NSIGHT_SYSTEMS_VERSION=2024.2.3

ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${CUDA_HOME}/lib64

RUN --mount=type=cache,id=pipcache,dst=/root/.cache/pip,mode=0777,Z \
    dnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
        ${PYTHON} ${PYTHON}-pip ${PYTHON}-devel findutils git-core gcc gcc-c++ which

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone https://github.com/facebookresearch/detectron2.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd detectron2 && \
    MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel && \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /workspace/detectron2/dist/*.whl
#    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install -e detectron2

RUN --mount=type=cache,id=pipcache,dst=/root/.cache/pip,mode=0777,Z \
    git clone https://github.com/pytorch/benchmark.git

RUN --mount=type=cache,id=pipcache,dst=/root/.cache/pip,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    ${PYTHON} -m pip list && \
    cd /workspace/benchmark && \
    export LD_LIBRARY_PATH=/usr/lib:/usr/lib64:${LD_LIBRARY_PATH} && \
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/workspace/venv/lib/python3.11/site-packages/pillow.libs && \
    echo ${LD_LIBRARY_PATH} && \
    ${PYTHON} install.py

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

#FROM nvcr.io/nvidia/cuda:12.4.1-cudnn-devel-ubi9
#
#ARG PYTHON_VERSION=3.11
#ENV PYTHON_VERSION=3.11
#ENV PYTHON=python${PYTHON_VERSION}
#ENV MAX_JOBS=$(nproc)
#ENV VIRTUAL_ENV=/workspace/venv
#
#RUN --mount=type=cache,id=pipcache,dst=/root/.cache/pip,mode=0777,Z \
#    dnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
#        ${PYTHON} ${PYTHON}-pip ${PYTHON}-devel findutils git-core which && \
#    dnf clean all
#
#COPY --from=builder /workspace/venv /workspace/venv
#COPY --from=builder /workspace/benchmark /workspace/benchmark

WORKDIR /workspace/benchmark
