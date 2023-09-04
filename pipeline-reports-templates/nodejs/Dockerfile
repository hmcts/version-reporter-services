FROM node:20

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . /app

ENV COSMOS_KEY="" \
    COSMOS_DB_NAME="" \
    COSMOS_DB_CONTAINER="" \
    COSMOS_DB_URI=""

EXPOSE 80
CMD ["npm", "start"]
