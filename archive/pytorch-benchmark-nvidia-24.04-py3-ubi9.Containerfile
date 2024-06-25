# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/pytorch-devel:nvidia-24.04-py3-ubi9

ARG PYTHON_VERSION=3.11
ENV PYTHON_VERSION=3.11
ENV PYTHON=python${PYTHON_VERSION}
#ENV VIRTUAL_ENV=/workspace/venv

ARG CUDA_VERSION=12.4
ARG CUDA_DASHED_VERSION=12-4

ENV LD_LIBRARY_PATH=/usr/lib:/usr/lib64:${LD_LIBRARY_PATH}:${CUDA_HOME}/lib64

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

## Force the version of "accelerate", so it doesn't use torch.distributed.checkpoint.format_utils
## It should be present in PyTorch 2.3.0, but for an unknown reason it's not there
#RUN --mount=type=cache,id=pipcache,dst=/root/.cache/pip,mode=0777,Z \
#    source ${VIRTUAL_ENV}/bin/activate && \
#    ${PYTHON} -m pip install "accelerate<0.31.0"

RUN --mount=type=cache,id=pipcache,dst=/root/.cache/pip,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd benchmark && \
    export LD_LIBRARY_PATH=/usr/lib:/usr/lib64:${LD_LIBRARY_PATH} && \
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/workspace/venv/lib/python3.11/site-packages/pillow.libs && \
    MAX_JOBS=$(nproc) ${PYTHON} install.py

ENV PYTHONIOENCODING=utf-8

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
