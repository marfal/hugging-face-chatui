# syntax=docker/dockerfile:1
# read the doc: https://huggingface.co/docs/hub/spaces-sdks-docker
# you will also find guides on how best to write your Dockerfile

FROM node:20 AS builder

WORKDIR /app

COPY https://raw.githubusercontent.com/huggingface/chat-ui/main/package-lock.json https://raw.githubusercontent.com/huggingface/chat-ui/main/package.json .

ARG APP_BASE=
ARG PUBLIC_APP_COLOR=blue
ENV BODY_SIZE_LIMIT=15728640

RUN --mount=type=cache,target=/app/.npm \
        npm set cache /app/.npm && \
        npm ci

COPY https://github.com/huggingface/chat-ui.git .

RUN npm run build

# mongo image
FROM mongo:7 AS mongo

# image to be used if INCLUDE_DB is false
FROM node:20-slim AS local_db_false

# image to be used if INCLUDE_DB is true
FROM node:20-slim AS local_db_true

RUN apt-get update
RUN apt-get install gnupg curl -y
# copy mongo from the other stage
COPY --from=mongo /usr/bin/mongo* /usr/bin/

ENV MONGODB_URL=mongodb://localhost:27017
RUN mkdir -p /data/db
RUN chown -R 1000:1000 /data/db

# final image
FROM local_db_false AS final

# build arg to determine if the database should be included
ARG INCLUDE_DB=false
ENV INCLUDE_DB=${INCLUDE_DB}

# svelte requires APP_BASE at build time so it must be passed as a build arg
ARG APP_BASE=
# tailwind requires the primary theme to be known at build time so it must be passed as a build arg
ARG PUBLIC_APP_COLOR=blue
ENV BODY_SIZE_LIMIT=15728640

# install dotenv-cli
RUN npm install -g dotenv-cli

# switch to a user that works for spaces
RUN userdel -r node
RUN useradd -m -u 1000 user
USER user

ENV HOME=/home/user \
	PATH=/home/user/.local/bin:$PATH

WORKDIR /app

# add a .env.local if the user doesn't bind a volume to it
RUN touch /app/.env.local

# get the default config, the entrypoint script and the server script
COPY https://raw.githubusercontent.com/huggingface/chat-ui/main/.env https://raw.githubusercontent.com/huggingface/chat-ui/main/entrypoint.sh https://raw.githubusercontent.com/huggingface/chat-ui/main/gcp-oauth2-service-account-credentials.json .

#import the build & dependencies
COPY --from=builder /app/build /app/build
COPY --from=builder /app/node_modules /app/node_modules

RUN npx playwright install

USER root
RUN npx playwright install-deps
USER user

RUN chmod +x /app/entrypoint.sh

CMD ["/bin/bash", "-c", "/app/entrypoint.sh"]
