FROM python:3

ENV PIP_BREAK_SYSTEM_PACKAGES 1

RUN apt-get update && apt-get install -y git
RUN useradd cveinfo

WORKDIR /app

RUN chown -R cveinfo:cveinfo /app
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
    MAX_BATCH_SIZE=1000

USER cveinfo

CMD ["/app/entrypoint.sh"]