FROM node:18

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . /app

ENV COSMOSDB_URI="" \
    COSMOSDB_PRIMARY_KEY="" \
    COSMOSDB_DATABASE="" \
    COSMOSDB_CONTAINER=""

EXPOSE 80
CMD ["npm", "start"]
