FROM alpine:3.22.2

ENV PIP_BREAK_SYSTEM_PACKAGES 1

RUN apk update && apk add curl coreutils yq jq openssl github-cli uuidgen bash python3 py3-pip

WORKDIR /app

COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .

# VAULT NAME is used when sourcing secrets from volume mounts
# SECRET PATH is used if a custom file path is used for those mounts (default: /mnt/secrets/)

ENV VAULT_NAME="" \
    SECRET_PATH="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI="" \
    DESIRED_VERSION="" \
    ENVIRONMENT="" \
    SERVER_IP="" \
    HUB_SUBSCRIPTION_ID=""

RUN chmod +x /app/set_env.sh

CMD ["/app/entrypoint.sh"]
