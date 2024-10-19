# syntax=docker/dockerfile:1
# read the doc: https://huggingface.co/docs/hub/spaces-sdks-docker
# you will also find guides on how best to write your Dockerfile

FROM node:20 AS builder

WORKDIR /app

COPY --link --chown=1000 package-lock.json package.json ./

ARG APP_BASE=
ARG PUBLIC_APP_COLOR=blue
ENV BODY_SIZE_LIMIT=15728640

RUN --mount=type=cache,target=/app/.npm \
        npm set cache /app/.npm && \
        npm ci

COPY --link --chown=1000 . .

RUN git config --global --add safe.directory /app && \
    PUBLIC_COMMIT_SHA=$(git rev-parse HEAD) && \
    echo "PUBLIC_COMMIT_SHA=$PUBLIC_COMMIT_SHA" >> /app/.env && \
    npm run build

FROM node:20-slim AS final

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
COPY --chown=1000 package.json /app/package.json
COPY --chown=1000 .env /app/.env
COPY --chown=1000 entrypoint.sh /app/entrypoint.sh
COPY --chown=1000 gcp-*.json /app/

#import the build & dependencies
COPY --from=builder --chown=1000 /app/build /app/build
COPY --from=builder --chown=1000 /app/node_modules /app/node_modules

RUN npx playwright install

USER root
RUN npx playwright install-deps
USER user

RUN chmod +x /app/entrypoint.sh

ENV MONGODB_URL=mongodb://mongo:27017

CMD ["/bin/bash", "-c", "/app/entrypoint.sh"]
