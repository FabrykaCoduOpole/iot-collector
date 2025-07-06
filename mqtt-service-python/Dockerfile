FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /app/certs

ENV PORT=3001
ENV PYTHONUNBUFFERED=1

EXPOSE 3001

CMD python sub.py \
    --endpoint a2s082f26l8xct-ats.iot.us-east-1.amazonaws.com \
    --ca_file /app/certs/root-CA.crt \
    --cert /app/certs/certificate.pem.crt \
    --key /app/certs/private.pem.key \
    --client_id basicPubSub \
    --topic sdk/test/python \
    --count 0