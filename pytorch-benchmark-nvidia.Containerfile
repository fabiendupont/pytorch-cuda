# vim: syntax=dockerfile expandtab tabstop=4 shiftwidth=4
FROM nvcr.io/nvidia/pytorch:24.04-py3

ENV MAX_JOBS=$(nproc)

RUN apt-get update && apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/*

RUN --mount=type=cache,id=pipcache,dst=/root/.cache/pip,mode=0777,Z \
    git clone https://github.com/pytorch/audio.git && \
    cd audio && \
    PYTORCH_VERSION=$(pip show torch | grep 'Version' | awk '{ print $2; }') python3 setup.py develop

# Workaround to allow installing detectron2_fasterrcnn models
# Reference: https://github.com/Tps-F/sd-webui-blip2/issues/24
RUN python3 -m pip uninstall -y opencv && \
    python3 -m pip install "opencv-python==4.9.0.80" && \
    rm /usr/local/lib/python3.10/dist-packages/cv2/typing/__init__.py

RUN --mount=type=cache,id=pipcache,dst=/root/.cache/pip,mode=0777,Z \
    git clone https://github.com/pytorch/benchmark.git && \
    cd benchmark && \
    python3 install.py

WORKDIR /workspace/benchmark
