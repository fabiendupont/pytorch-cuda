# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/pytorch-devel:2.3.0-ubi9-nvcr

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ARG VIRTUAL_ENV=/workspace/venv

ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV PS1="(venv) ${PS1:-}"
ENV VIRTUAL_ENV_PROMPT="(venv) "

ARG LLAMA_CPP_PYTHON_VERSION=0.2.75
ARG INSTRUCTLAB_VERSION=0.16.1

WORKDIR /workspace

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${INSTRUCTLAB_VERSION} https://github.com/instructlab/instructlab.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    CMAKE_ARGS="-DLLAMA_CUDA=on -DLLAMA_CUBLAS=on" ${PYTHON} -m pip install --force-reinstall --no-cache-dir "llama-cpp-python==${LLAMA_CPP_PYTHON_VERSION}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd instructlab && \
    ${PYTHON} -m pip install instructlab

WORKDIR /instructlab
