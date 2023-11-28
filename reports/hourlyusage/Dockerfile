FROM python:3.12.0-alpine3.18

WORKDIR /usr/src/app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN chmod 777 /usr/src/app/output.csv
RUN ls -ln /usr/src/app/output.csv

ENV AZURE_STORAGE_CONTAINER="" \
    AZURE_STORAGE_URL="" \
    AZURE_STORAGE_ACCESS_KEY="" \
    AZURE_TENANT_ID="" \
    AZURE_CLIENT_ID="" \
    AZURE_CLIENT_SECRET="" \
    ENVIRONMENT="" \
    CLUSTER_NAME=""

CMD [ "python", "./main.py" ]