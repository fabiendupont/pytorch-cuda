# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM nvcr.io/nvidia/cuda:12.4.1-cudnn-devel-ubi9

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ARG VIRTUAL_ENV=/workspace/venv
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

ARG PYTORCH_VERSION=2.3.0
ARG PYTORCH_AUDIO_VERSION=2.3.0
ARG PYTORCH_TEXT_VERSION=0.18.0
ARG PYTORCH_VISION_VERSION=0.18.0
ARG NVIDIA_FUSER_VERSION=0.0.13

RUN dnf -y install --nobest --nodocs --setopt=install_weak_deps=False --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        ${PYTHON} ${PYTHON}-pip ${PYTHON}-devel ${PYTHON}-pybind11-devel git-core libglvnd-glx ninja-build && \
    dnf clean all && \
    ${PYTHON} -m venv ${VIRTUAL_ENV} && \
    mkdir -p /root/.local/bin

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install numpy pyaml typing_extensions wheel

ENV CCACHE_DIR="/root/.cache/ccache"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    dnf -y install --nobest --nodocs --setopt=install_weak_deps=0 --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        ccache && \
    dnf clean all && \
    mkdir -p ${CCACHE_DIR}

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ln -s /usr/bin/ccache /root/.local/bin/gcc && \
    ln -s /usr/bin/ccache /root/.local/bin/g++ && \
    ln -s /usr/bin/ccache /root/.local/bin/cc && \
    ln -s /usr/bin/ccache /root/.local/bin/c++ && \
    ln -s /usr/bin/ccache /root/.local/bin/cc1plus

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ln -s /usr/bin/ccache /root/.local/bin/nvcc && \
    ln -s /usr/bin/ccache /root/.local/bin/cicc && \
    ln -s /usr/bin/ccache /root/.local/bin/ptxas

WORKDIR /workspace

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_VERSION} https://github.com/pytorch/pytorch.git && \
    cd pytorch && \
    git submodule sync && \
    git submodule update --init --recursive

ENV TORCH_CUDA_ARCH_LIST="7.0 7.5 8.0 8.6 8.7 8.9 9.0"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    cd /workspace/pytorch && \
    PYTORCH_BUILD_VERSION=${PYTORCH_VERSION} PYTORCH_BUILD_NUMBER=0 MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /workspace/pytorch/dist/*.whl

ENV PYTORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"
ENV TORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"

ENV PATH="${PYTORCH_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_HOME}/include:${CMAKE_INCLUDE_PATH}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_AUDIO_VERSION} https://github.com/pytorch/audio.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/audio && \
    BUILD_VERSION=${PYTORCH_AUDIO_VERSION} USE_CUDA=1 BUILD_SOX=0 MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel
#    PYTORCH_VERSION=$(${VIRTUAL_ENV}/bin/${PYTHON} -m pip show torch | grep 'Version:' | awk '{ print $2; }') BUILD_VERSION=${PYTORCH_AUDIO_VERSION} USE_CUDA=1 BUILD_SOX=0 MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /workspace/audio/dist/*.whl

ENV PYTORCH_AUDIO_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchaudio"

ENV PATH="${PYTORCH_AUDIO_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CMAKE_INCLUDE_PATH}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_VISION_VERSION} https://github.com/pytorch/vision.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/vision && \
    BUILD_VERSION=${PYTORCH_VISION_VERSION} FORCE_CUDA=1 MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel
#    PYTORCH_VERSION=$(${VIRTUAL_ENV}/bin/${PYTHON} -m pip show torch | grep 'Version:' | awk '{ print $2; }') BUILD_VERSION=${PYTORCH_VISION_VERSION} FORCE_CUDA=1 MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /workspace/vision/dist/*.whl

ENV PYTORCH_AUDIO_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torchaudio"

ENV PATH="${PYTORCH_AUDIO_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${PYTORCH_AUDIO_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${PYTORCH_AUDIO_HOME}/include:${CMAKE_INCLUDE_PATH}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    dnf update -y --nodocs --nobest --setopt=install_weak_deps=False && \
    dnf install -y --nodocs --nobest --setopt=install_weak_deps=False \
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
    dnf clean all

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/bash"]
