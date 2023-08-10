FROM alpine:3.18.3

RUN apk update && apk add curl coreutils yq jq openssl github-cli uuidgen bash
RUN apk update && apk add python3 py3-pip && pip3 install azure-cosmos pytz


WORKDIR /app

COPY . .

ENV COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI="" \
    MAX_DAYS_AWAY=3 \
    MAX_REPOS=300 \
    GITHUB_TOKEN=""

CMD ["/app/renovate-prs.sh"]
