FROM alpine/k8s:1.31.2

ENV PIP_BREAK_SYSTEM_PACKAGES 1

RUN apk update && apk add git github-cli bash python3 py3-pip
RUN pip3 install azure-cosmos pytz

WORKDIR /app

RUN chmod 755 /app

COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .

# VAULT NAME is used when sourcing secrets from volume mounts
# SECRET PATH is used if a custom file path is used for those mounts (default: /mnt/secrets/)

ENV COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI="" \
    SECRET_PATH="" \
    VAULT_NAME="" \
    MAX_BATCH_SIZE=1000


RUN chmod +x /app/set_env.sh

CMD ["/app/entrypoint.sh"]