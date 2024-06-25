# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/pytorch-devel:nvidia-24.04-py3-ubi9 as builder

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ENV VIRTUAL_ENV=/opt/${PYTHON}/venv

ARG NEMO_VERSION=1.23.0

RUN microdnf -y update --nobest --nodocs --setopt=install_weak_deps=0  && \
    microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 git-core && \
    microdnf clean all

WORKDIR /workspace

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${NEMO_VERSION} https://github.com/NVIDIA/NeMo.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone https://github.com/NVIDIA/Megatron-LM.git && \
    cd Megatron-LM && \
    git checkout 02871b4df8c69fac687ab6676c4246e936ce92d0 && \
    . ${VIRTUAL_ENV}/bin/activate && \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install pybind11 && \
    MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

# Performance optimizations for distributed optimizer: https://github.com/NVIDIA/apex/pull/1771
RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone https://github.com/NVIDIA/apex.git && \
    cd apex && \
    git checkout f058162b215791b15507bb542f22ccfde49c872d && \
    MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    cd /workspace/NeMo && \
    MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

FROM quay.io/fabiendupont/pytorch-devel:nvidia-24.04-py3-ubi9

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ENV VIRTUAL_ENV=/opt/${PYTHON}/venv

# install nemo dependencies
WORKDIR /tmp/nemo
ENV LHOTSE_REQUIRE_TORCHAUDIO=0
COPY --from=builder /workspace/NeMo/requirements .
RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install Cython && \
    for f in $(ls requirements*.txt); do ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install --disable-pip-version-check --no-cache-dir -r $f; done

COPY --from=builder /workspace/NeMo/dist/*.whl /tmp/wheel/
COPY --from=builder /workspace/Megatron-LM/dist/*.whl /tmp/wheel/
COPY --from=builder /workspace/apex/dist/*.whl /tmp/wheel/

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /tmp/wheel/*.whl && \
    rm -rf /tmp/wheel

# copy scripts/examples/tests into container for end user
COPY --from=builder /workspace/NeMo/scripts /opt/NeMo/scripts
COPY --from=builder /workspace/NeMo/examples /opt/NeMo/examples
COPY --from=builder /workspace/NeMo/tests /opt/NeMo/tests
COPY --from=builder /workspace/NeMo/tutorials /opt/NeMo/tutorials

WORKDIR /workspace

