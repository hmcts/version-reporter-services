FROM python:3.13-slim

RUN apt-get -y update && apt-get -y install git

WORKDIR /app

ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Install dependencies:
COPY . .
RUN pip install -r requirements.txt

# Run the application:

ENV COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI="" \
    SECRET_PATH="" \
    VAULT_NAME="" \
    MAX_BATCH_SIZE=1000

RUN chmod +x /app/set_env.sh

CMD ["/app/entrypoint.sh"]