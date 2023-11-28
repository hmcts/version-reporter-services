FROM python:3.12.0-alpine3.18

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

RUN useradd -ms /bin/bash admin
COPY . .

RUN chown -R admin:admin /usr/src/app
RUN chmod 755 /usr/src/app

USER admin

ENV AZURE_STORAGE_CONTAINER="" \
    AZURE_STORAGE_URL="" \
    AZURE_STORAGE_ACCESS_KEY="" \
    AZURE_TENANT_ID="" \
    AZURE_CLIENT_ID="" \
    AZURE_CLIENT_SECRET="" \
    ENVIRONMENT="" \
    CLUSTER_NAME=""

CMD [ "python", "./main.py" ]