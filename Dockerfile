# 1. Create an image to build n8n
FROM node:16-alpine as builder

# Update everything and install needed dependencies
USER root

# Install all needed dependencies
RUN apk --update add --virtual build-dependencies python3 build-base ca-certificates git && \
	npm_config_user=root npm install -g npm@latest run-script-os turbo

WORKDIR /data

COPY turbo.json .
COPY package.json .
COPY package-lock.json .
COPY packages/cli/ ./packages/cli/
COPY packages/core/ ./packages/core/
COPY packages/design-system/ ./packages/design-system/
COPY packages/editor-ui/ ./packages/editor-ui/
COPY packages/nodes-base/ ./packages/nodes-base/
COPY packages/workflow/ ./packages/workflow/
RUN rm -rf node_modules packages/*/node_modules packages/*/dist

RUN npm config set legacy-peer-deps true
RUN npm install --loglevel notice
RUN npm run build


# 2. Start with a new clean image with just the code that is needed to run n8n
FROM node:16-alpine

ARG N8N_VERSION=0.189.1

RUN if [ -z "$N8N_VERSION" ] ; then echo "The N8N_VERSION argument is missing!" ; exit 1; fi

# Update everything and install needed dependencies
RUN apk add --update graphicsmagick tzdata git su-exec jq tini

# # Set a custom user to not have n8n run as root
USER root

# Install n8n and the also temporary all the packages
# it needs to build it correctly.
RUN apk --update add --virtual build-dependencies python3 build-base ca-certificates && \
    npm_config_user=root npm install -g full-icu n8n@${N8N_VERSION} && \
    apk del build-dependencies

# Install fonts
RUN apk --no-cache add --virtual fonts msttcorefonts-installer fontconfig && \
    update-ms-fonts && \
    fc-cache -f && \
    apk del fonts && \
    find  /usr/share/fonts/truetype/msttcorefonts/ -type l -exec unlink {} \;

ENV NODE_ICU_DATA /usr/local/lib/node_modules/full-icu

COPY --from=builder /data ./

COPY docker/images/n8n-custom/docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

EXPOSE 5678/tcp
