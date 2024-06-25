# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/pytorch-devel:2.3.0-ubi9-nvcr AS builder

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ENV PYTHON=${PYTHON}
ARG VIRTUAL_ENV=/workspace/venv
ENV VIRTUAL_ENV=${VIRTUAL_ENV}
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/opt/nvidia/nsight-systems/${NSIGHT_SYSTEMS_VERSION}/host-linux-x64/Mesa"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone https://github.com/facebookresearch/detectron2.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd detectron2 && \
    MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel && \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /workspace/detectron2/dist/*.whl
#    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install -e detectron2 && \
#    rm -rf detectron2

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth=1 https://github.com/pytorch/benchmark.git

ENV LD_LIBRARY_PATH="/usr/lib64:${LD_LIBRARY_PATH}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/benchmark && \
    MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} install.py

#FROM quay.io/fabiendupont/pytorch-runtime:2.3.0-ubi9
FROM registry.redhat.io/ubi9/ubi-minimal:9.4

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ENV PYTHON=${PYTHON}
ARG VIRTUAL_ENV=/workspace/venv
ENV VIRTUAL_ENV=${VIRTUAL_ENV}
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    microdnf update -y --nodocs --nobest --setopt=install_weak_deps=0 && \
    microdnf install -y --nodocs --nobest --setopt=install_weak_deps=0 \
        ${PYTHON} ${PYTHON}-pip \
        compat-openssl11 \
        findutils \
        gtk3 \
        libglvnd-glx \
        libgomp \
        libICE \
        libSM \
        libXcomposite \
        libXdamage \
        libXi \
        libXrandr \
        libXtst \
        libwayland-egl \
        libxkbcommon \
        libxkbcommon-x11 \
        libxkbfile.so.1 \
        nspr \
        nss \
        nss-util \
        xcb-util-cursor \
    && \
    microdnf clean all

COPY --from=builder /workspace/venv /workspace/venv/
COPY --from=builder /workspace/benchmark /workspace/benchmark
COPY --from=builder /workspace/detectron2/dist/*.whl /tmp/wheel/

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /tmp/wheel/*.whl && \
    find ${VIRTUAL_ENV} -name __pycache__ | xargs rm -rf && \
    rm -rf /tmp/wheel

ENV LD_LIBRARY_PATH="/usr/lib:${LD_LIBRARY_PATH}"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/cuda/compute-sanitizer"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/lib64/tracker-miners-3.0"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/workspace/venv/lib/python3.11/site-packages/h5py.libs"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/workspace/venv/lib/python3.11/site-packages/opencv_python.libs"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${VIRTUAL_ENV}/lib/${PYTHON}/site-packages/pygame.libs"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${VIRTUAL_ENV}/lib/${PYTHON}/site-packages/Shapely.libs"

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

WORKDIR /workspace/benchmark
