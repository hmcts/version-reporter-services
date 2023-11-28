FROM alpine:3.18.4

RUN apk update && apk add python3 py3-pip

WORKDIR /app

COPY requirements.txt ./

RUN pip install pendulum==2.0.5
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV AZURE_STORAGE_CONTAINER="" \
    AZURE_STORAGE_URL="" \
    AZURE_STORAGE_ACCESS_KEY="" \
    AZURE_TENANT_ID="" \
    AZURE_CLIENT_ID="" \
    AZURE_CLIENT_SECRET="" \
    ENVIRONMENT="" \
    CLUSTER_NAME=""

CMD [ "python", "./main.py" ]