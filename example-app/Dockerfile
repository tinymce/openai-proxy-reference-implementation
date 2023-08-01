FROM node:lts

COPY index.html ai-request.js index.js package.json package-lock.json /app/

WORKDIR /app

RUN npm install

ENV EXAMPLE_APP_JWT_SECRET="Default JWT secret"

ENTRYPOINT [ "node", "index.js" ]