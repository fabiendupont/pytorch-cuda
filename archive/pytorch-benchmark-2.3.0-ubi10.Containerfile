# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM quay.io/fabiendupont/python-devel:2.3.0-ubi10-nvcr AS build

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ARG VIRTUAL_ENV=/workspace/venv
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

ENV CCACHE_DIR=/root/.cache/ccache

ARG NVIDIA_DRIVER_STREAM=550
ARG CUDA_VERSION=12.4
ARG CUDA_MAJOR_VERSION=12
ARG CUDA_DASHED_VERSION=12-4
ARG CUDNN_MAJOR_VERSION=9
ARG NCCL_VERSION=2.21.5

ARG PYTORCH_VERSION=2.3.0
ARG PYTORCH_AUDIO_VERSION=2.3.0
ARG PYTORCH_TEXT_VERSION=0.18.0
ARG PYTORCH_VISION_VERSION=0.18.0
ARG NVIDIA_FUSER_VERSION=0.0.13

RUN microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        ${PYTHON} ${PYTHON}-pip ${PYTHON}-devel ${PYTHON}-pybind11-devel \
        autoconf automake cargo cmake findutils gcc gcc-c++ git-core ninja-build openssl-devel rust which \
        automake gcc-fortran libffi libffi-devel \
        libjpeg-turbo libjpeg-turbo-devel libpng libpng-devel \
        openblas openblas-devel openmpi openmpi-devel && \
        rdma-core rdma-core-devel && \
    microdnf clean all && \
    ${PYTHON} -m venv ${VIRTUAL_ENV} && \
    mkdir -p /root/.local/bin

ENV OPENMPI_HOME="/usr/lib64/openmpi"

ENV PATH="/${OPENMPI_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${OPENMPI_HOME}/lib64:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${OPENMPI_HOME}/lib64:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${OPENMPI_HOME}/lib:${CUDA_HOME}/lib64:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${OPENMPI_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${OPENMPI_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${OPENMPI_HOME}/include:${CMAKE_INCLUDE_PATH}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        ccache && \
    microdnf clean all && \
    mkdir -p ${CCACHE_DIR}

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ln -s /usr/bin/ccache /root/.local/bin/gcc && \
    ln -s /usr/bin/ccache /root/.local/bin/g++ && \
    ln -s /usr/bin/ccache /root/.local/bin/cc && \
    ln -s /usr/bin/ccache /root/.local/bin/c++ && \
    ln -s /usr/bin/ccache /root/.local/bin/cc1plus

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ln -s /usr/bin/ccache /root/.local/bin/mpiCC && \
    ln -s /usr/bin/ccache /root/.local/bin/mpicc && \
    ln -s /usr/bin/ccache /root/.local/bin/mpic++ && \
    ln -s /usr/bin/ccache /root/.local/bin/mpicxx && \
    ln -s /usr/bin/ccache /root/.local/bin/orteCC && \
    ln -s /usr/bin/ccache /root/.local/bin/ortecc && \
    ln -s /usr/bin/ccache /root/.local/bin/ortec++ && \
    ln -s /usr/bin/ccache /root/.local/bin/ortecxx && \
    ln -s /usr/bin/ccache /root/.local/bin/oshCC && \
    ln -s /usr/bin/ccache /root/.local/bin/oshcc && \
    ln -s /usr/bin/ccache /root/.local/bin/oshc++ && \
    ln -s /usr/bin/ccache /root/.local/bin/oshcxx && \
    ln -s /usr/bin/ccache /root/.local/bin/shmemCC && \
    ln -s /usr/bin/ccache /root/.local/bin/shmemcc && \
    ln -s /usr/bin/ccache /root/.local/bin/shmemc++ && \
    ln -s /usr/bin/ccache /root/.local/bin/shmemmcxx

# Installing NVIDIA CUDA packages
RUN curl -sL -o /etc/yum.repos.d/cuda.repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && \
    microdnf -y module enable nvidia-driver:${NVIDIA_DRIVER_STREAM} && \
    microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
        cuda-cccl-${CUDA_DASHED_VERSION} \
        cuda-cudart-${CUDA_DASHED_VERSION} cuda-cudart-devel-${CUDA_DASHED_VERSION} \
        cuda-cupti-${CUDA_DASHED_VERSION} \
        cuda-driver-devel-${CUDA_DASHED_VERSION} \
        cuda-nvcc-${CUDA_DASHED_VERSION} \
        cuda-nvml-devel-${CUDA_DASHED_VERSION} \
        cuda-nvprof-${CUDA_DASHED_VERSION} \
        cuda-nvrtc-${CUDA_DASHED_VERSION} cuda-nvrtc-devel-${CUDA_DASHED_VERSION} \
        cuda-nvtx-${CUDA_DASHED_VERSION} \
        cuda-profiler-api-${CUDA_DASHED_VERSION} \
        libcublas-${CUDA_DASHED_VERSION} libcublas-devel-${CUDA_DASHED_VERSION} \
        libcudnn${CUDNN_MAJOR_VERSION}-cuda-${CUDA_MAJOR_VERSION} libcudnn${CUDNN_MAJOR_VERSION}-devel-cuda-${CUDA_MAJOR_VERSION} \
        libcufft-${CUDA_DASHED_VERSION} libcufft-devel-${CUDA_DASHED_VERSION} \
        libcurand-${CUDA_DASHED_VERSION} libcurand-devel-${CUDA_DASHED_VERSION} \
        libcusolver-${CUDA_DASHED_VERSION} libcusolver-devel-${CUDA_DASHED_VERSION} \
        libcusparse-${CUDA_DASHED_VERSION} libcusparse-devel-${CUDA_DASHED_VERSION} libcusparselt0 libcusparselt-devel \
        libnccl-${NCCL_VERSION}-1+cuda${CUDA_VERSION} libnccl-devel-${NCCL_VERSION}-1+cuda${CUDA_VERSION} \
        libnvfatbin-${CUDA_DASHED_VERSION} libnvfatbin-devel-${CUDA_DASHED_VERSION} \
        libnvjitlink-${CUDA_DASHED_VERSION} libnvjitlink-devel-${CUDA_DASHED_VERSION} \
        libnvjpeg-${CUDA_DASHED_VERSION} libnvjpeg-devel-${CUDA_DASHED_VERSION} \
        libnpp-${CUDA_DASHED_VERSION} libnpp-devel-${CUDA_DASHED_VERSION} \
        nvidia-driver-NVML && \
    microdnf clean all

ENV CUDA_HOME="/usr/local/cuda"

ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${CUDA_HOME}/lib64:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${CUDA_HOME}/lib64:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${CUDA_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${CUDA_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${CUDA_HOME}/include:${CMAKE_INCLUDE_PATH}"

ENV NCCL_LIB_DIR="${CUDA_HOME}/lib64"
ENV NCCL_INCLUDE_DIR="${CUDA_HOME}/include"
ENV XLA_TARGET="cuda124"
ENV XLA_FLAGS="--xla_gpu_cuda_data_dir=${CUDA_HOME}"
ENV CMAKE_ARGS="-DLLAMA_CUBLAS=on"
ENV CFLAGS="-mno-avx"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ln -s /usr/bin/ccache /root/.local/bin/nvcc && \
    ln -s /usr/bin/ccache /root/.local/bin/cicc && \
    ln -s /usr/bin/ccache /root/.local/bin/ptxas

# Installing Intel OneAPI MKL packages
COPY ./oneapi.repo /etc/yum.repos.d/oneapi.repo

RUN microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
        intel-oneapi-mkl-core intel-oneapi-mkl-core-devel && \
    microdnf clean all

ENV INTEL_MKL_HOME="/opt/intel/oneapi/mkl/latest"

ENV PATH="${INTEL_MKL_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${LIBRARY_PATH}"
ENV CMAKE_LIBRARY_PATH="${INTEL_MKL_HOME}/lib:${CMAKE_LIBRARY_PATH}"
ENV C_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${C_INCLUDE_PATH}"
ENV CPLUS_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${CPLUS_INCLUDE_PATH}"
ENV CMAKE_INCLUDE_PATH="${INTEL_MKL_HOME}/include:${CMAKE_INCLUDE_PATH}"

WORKDIR /workspace

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install numpy pyaml typing_extensions wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_VERSION} https://github.com/pytorch/pytorch.git && \
    cd pytorch && \
    git submodule sync && \
    git submodule update --init --recursive

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    cd /workspace/pytorch && \
    TORCH_CUDA_ARCH_LIST="8.0 8.6 8.7 9.0" MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

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

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    git clone --depth 1 -b v${NVIDIA_FUSER_VERSION} https://github.com/NVIDIA/Fuser.git && \
#    cd Fuser && \
#    git submodule sync --recursive && \
#    git submodule update --init --recursive
#
#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    cd /workspace/Fuser && \
#    Torch_DIR=${PYTORCH_HOME}/share/cmake/Torch TORCH_CUDA_ARCH_LIST="8.0 8.6 8.7 9.0" MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel
#
#RUN ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /workspace/Fuser/dist/*.whl

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_AUDIO_VERSION} https://github.com/pytorch/audio.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/audio && \
    PYTORCH_VERSION=$(${VIRTUAL_ENV}/bin/${PYTHON} -m pip show torch | grep 'Version:' | awk '{ print $2; }') TORCH_CUDA_ARCH_LIST="7.0 8.0 8.6 9.0" MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_TEXT_VERSION} https://github.com/pytorch/text.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    git clone --depth 1 -b v${PYTORCH_VISION_VERSION} https://github.com/pytorch/vision.git

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/text && \
    PYTORCH_VERSION=$(${VIRTUAL_ENV}/bin/${PYTHON} -m pip show torch | grep 'Version:' | awk '{ print $2; }') TORCH_CUDA_ARCH_LIST="7.0 8.0 8.6 9.0" FORCE_CUDA=1 MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

#RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
#    microdnf install -y --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
#        ${PYTHON}-pybind11-devel \
#        ffmpeg-free ffmpeg-free-devel \
#        libswscale-free libswscale-free-devel \
#        libavcodec-free libavcodec-free-devel \
#        libswresample-free libswresample-free-devel \
#        libavformat-free libavformat-free-devel \
#        libavutil-free libavutil-free-devel \
#        libjpeg-turbo libjpeg-turbo-devel \
#        libpng libpng-devel && \
#    microdnf clean all

#ENV C_INCLUDE_PATH="/usr/include/ffmpeg:${C_INCLUDE_PATH}"
#ENV CPLUS_INCLUDE_PATH="/usr/include/ffmpeg:${CPLUS_INCLUDE_PATH}"
#ENV CMAKE_INCLUDE_PATH="/usr/include/ffmpeg:${CMAKE_INCLUDE_PATH}"

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    source ${VIRTUAL_ENV}/bin/activate && \
    cd /workspace/vision && \
    PYTORCH_VERSION=$(${VIRTUAL_ENV}/bin/${PYTHON} -m pip show torch | grep 'Version:' | awk '{ print $2; }') TORCH_CUDA_ARCH_LIST="7.0 8.0 8.6 9.0" FORCE_CUDA=1 MAX_JOBS=$(nproc) ${VIRTUAL_ENV}/bin/${PYTHON} setup.py bdist_wheel

FROM registry.redhat.io/ubi9/ubi-minimal:9.4

ARG PYTHON_VERSION=3.11
ARG PYTHON=python${PYTHON_VERSION}
ARG VIRTUAL_ENV=/workspace/venv
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PYTHONIOENCODING=utf-8

ARG NVIDIA_DRIVER_STREAM=550
ARG CUDA_VERSION=12.4
ARG CUDA_MAJOR_VERSION=12
ARG CUDA_DASHED_VERSION=12-4
ARG CUDNN_MAJOR_VERSION=9
ARG NCCL_VERSION=2.21.5

ARG PYTORCH_VERSION=2.3.0
ARG PYTORCH_AUDIO_VERSION=2.3.0
ARG PYTORCH_VISION_VERSION=0.18.0

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    curl -sL -o /etc/yum.repos.d/cuda.repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && \
    microdnf -y module enable nvidia-driver:${NVIDIA_DRIVER_STREAM} && \
    microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
        ${PYTHON} ${PYTHON}-pip findutils which \
        libjpeg-turbo libpng \
        openblas openmpi \
        rdma-core \
        cuda-cccl-${CUDA_DASHED_VERSION} \
        cuda-cudart-${CUDA_DASHED_VERSION} \
        cuda-cupti-${CUDA_DASHED_VERSION} \
        cuda-nvcc-${CUDA_DASHED_VERSION} \
        cuda-nvprof-${CUDA_DASHED_VERSION} \
        cuda-nvrtc-${CUDA_DASHED_VERSION} \
        cuda-nvtx-${CUDA_DASHED_VERSION} \
        libcublas-${CUDA_DASHED_VERSION} \
        libcudnn${CUDNN_MAJOR_VERSION}-cuda-${CUDA_MAJOR_VERSION} \
        libcufft-${CUDA_DASHED_VERSION} \
        libcurand-${CUDA_DASHED_VERSION} \
        libcusolver-${CUDA_DASHED_VERSION} \
        libcusparse-${CUDA_DASHED_VERSION} libcusparselt0 \
        libnccl-${NCCL_VERSION}-1+cuda${CUDA_VERSION} \
        libnvfatbin-${CUDA_DASHED_VERSION} \
        libnvjitlink-${CUDA_DASHED_VERSION} \
        libnvjpeg-${CUDA_DASHED_VERSION} \
        libnpp-${CUDA_DASHED_VERSION} \
        nvidia-driver-NVML && \
    microdnf clean all && \
    ${PYTHON} -m venv ${VIRTUAL_ENV} && \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install wheel

COPY ./oneapi.repo /etc/yum.repos.d/oneapi.repo

RUN microdnf -y install --nobest --nodocs --setopt=install_weak_deps=0 \
        intel-oneapi-mkl && \
    microdnf clean all

COPY --from=builder /workspace/pytorch/dist/*.whl /tmp/wheel/
COPY --from=builder /workspace/audio/dist/*.whl /tmp/wheel/
COPY --from=builder /workspace/text/dist/*.whl /tmp/wheel/
COPY --from=builder /workspace/vision/dist/*.whl /tmp/wheel/

RUN --mount=type=cache,id=cache,dst=/root/.cache,mode=0777,Z \
    ${VIRTUAL_ENV}/bin/${PYTHON} -m pip install /tmp/wheel/*.whl && \
    rm -rf /tmp/wheel

ENV CUDA_HOME="/usr/local/cuda"
ENV NCCL_LIB_DIR="${CUDA_HOME}/lib64"
ENV INTEL_MKL_HOME="/opt/intel/oneapi/mkl/latest"
ENV PYTORCH_HOME="${VIRTUAL_ENV}/lib64/${PYTHON}/site-packages/torch"

ENV PATH="${CUDA_HOME}/bin:${INTEL_MKL_HOME}/bin:${PYTORCH_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${INTEL_MKL_HOME}/lib:${PYTORCH_HOME}/lib:${LD_LIBRARY_PATH}"
ENV LIBRARY_PATH="${CUDA_HOME}/lib64/stubs:${LIBRARY_PATH}"

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

ENV NVIDIA_REQUIRE_CUDA=cuda>=9.0
ENV CUDA_CACHE_DISABLE=1
ENV CUDA_MODULE_LOADING=LAZY
ENV NCCL_WORK_FIFO_DEPTH=4194304
ENV USE_EXPERIMENTAL_CUDNN_V8_API=1
ENV UCC_CL_BASIC_TLS=^sharp

ENV TORCH_CUDA_ARCH_LIST="8.0 8.6 8.7 9.0"
ENV TORCH_ALLOW_TF32_CUBLAS_OVERRIDE=1
ENV TORCH_CUDNN_V8_API_ENABLED=1
ENV PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
ENV OMPI_MCA_coll_hcoll_enable=0

ENV JUPYTER_PORT=8888
ENV TENSORBOARD_PORT=6006

WORKDIR /workspace
ENTRYPOINT ["source", "/workspace/venv/bin/activate"]
