FROM python:3.8-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r /app/requirements.txt

COPY provider-operator.py .
COPY minecraft-crd.yaml .

CMD ["python", "/app/provider-operator.py"]