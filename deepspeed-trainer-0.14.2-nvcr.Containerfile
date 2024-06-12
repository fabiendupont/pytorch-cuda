# # vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
#FROM nvcr.io/nvidia/cuda:12.1.1-cudnn8-devel-ubi9
FROM quay.io/fabiendupont/pytorch-devel:2.3.0-ubi9-nvcr

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ARG VIRTUAL_ENV=/workspace/venv

ARG DEEPSPEED_VERSION="0.14.2"
ARG TRANSFORMERS_VERSION="4.40.1"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    ${PYTHON} -m pip install deepspeed==${DEEPSPEED_VERSION}

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    ${PYTHON} -m pip install transformers==${TRANSFORMERS_VERSION}

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    ${PYTHON} -m pip install ipdb jupyterlab gpustat matplotlib hydra-core datasets rich numba

RUN git clone https://github.com/instructlab/training.git
RUN mkdir -p /ilab-data/training_output

WORKDIR /training
