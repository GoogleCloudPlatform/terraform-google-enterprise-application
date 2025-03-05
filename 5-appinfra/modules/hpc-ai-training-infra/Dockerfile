FROM tensorflow:latest-gpu
WORKDIR /data/tensorflow-mnist-example
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["/bin/bash", "-c", "--", "python tensorflow_mnist_train_distributed.py"]