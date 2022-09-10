FROM node:18.8.0-alpine3.16 as build

WORKDIR /app

COPY package.json yarn.lock ./

RUN yarn

COPY pages/ ./pages
COPY styles/ ./styles

RUN yarn build


FROM node:18.8.0-alpine3.16

WORKDIR /app


COPY --from=build app/package.json ./package.json

RUN yarn install --production

COPY --from=build app/.next ./.next

EXPOSE 3000

CMD ["yarn", "start"]

