FROM node:lts

COPY index.html index.js package.json package-lock.json /app/

WORKDIR /app

RUN npm install

ENTRYPOINT [ "node", "index.js" ]