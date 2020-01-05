ARG NPM_RUN_BUILD_OPTS

FROM node:10-stretch AS build

ENV NODE_ENV default
ENV NODE_CONFIG_DIR /config

# Install dependencies
RUN apt-get update \
    && apt-get -y install ffmpeg \
    && rm /var/lib/apt/lists/* -fR

WORKDIR /app

COPY . .

# Don't clear the cache here, we want to retain packages for fast dev builds
RUN yarn install --pure-lockfile \
    && npm run build -- --light 

FROM build AS dev

# Expose API and frontend
EXPOSE 3000 9000

CMD [ "npm", "run", "dev" ]

FROM node:10-stretch-slim AS production

WORKDIR /app

# Install dependencies
RUN apt-get update \
    && apt-get -y install ffmpeg \
    && rm /var/lib/apt/lists/* -fR

# Add peertube user
RUN groupadd -r peertube \
    && useradd -r -g peertube -m peertube

# grab gosu for easy step-down from root
RUN set -eux; \
	apt update; \
	apt install -y gosu; \
	rm -rf /var/lib/apt/lists/*; \
	gosu nobody true

# Install PeerTube
COPY --from=build /app/dist /app/dist
RUN chown -R peertube:peertube /app

USER peertube

RUN yarn install --pure-lockfile --production \
    && yarn cache clean

USER root

RUN mkdir /data /config
RUN chown -R peertube:peertube /data /config

ENV NODE_ENV production
ENV NODE_CONFIG_DIR /config

VOLUME /data
VOLUME /config

COPY ./support/docker/production/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Run the application
CMD ["npm", "start"]
EXPOSE 9000
