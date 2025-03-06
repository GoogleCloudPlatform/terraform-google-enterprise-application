FROM tensorflow/tensorflow:latest-gpu@sha256:1f16fbd9be8bb84891de12533e332bbd500511caeb5cf4db501dbe39d422f9c7
WORKDIR /data/tensorflow-mnist-example
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["/bin/bash", "-c", "--", "python tensorflow_mnist_train_distributed.py"]
