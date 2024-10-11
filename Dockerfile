ARG image=node:20-alpine

# == BUILDER == #
FROM --platform=${BUILDPLATFORM} ${image} AS builder

RUN apk add --no-cache curl

ARG ARTIFACTORY_USERNAME
ARG ARTIFACTORY_PASSWORD

WORKDIR /usr/src
COPY . /usr/src

RUN curl -Ls --user "${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD}" \
     https://lvt.jfrog.io/artifactory/api/npm/npm/auth/lvt > .npmrc

RUN --mount=type=cache,target=/root/node_modules npm install --no-package-lock
RUN npm run build:release

# == DEV == #
FROM ${image} AS dev

WORKDIR /usr/src
COPY --from=builder /usr/src/package.json /usr/src/package-lock.json /usr/src/.npmrc /usr/src/
RUN --mount=type=cache,target=/root/node_modules \
     npm install --no-package-lock

ENV PORT=3000
EXPOSE 3000
CMD [ "npm", "run", "dev"]

# == RUNTIME == #
FROM --platform=${TARGETPLATFORM} ${image} AS runtime

WORKDIR /opt/service

COPY --from=builder /usr/src/package.json /usr/src/package-lock.json /usr/src/.npmrc /opt/service/
RUN --mount=type=cache,target=/root/node_modules \
     npm install --no-package-lock --production

COPY --from=builder /usr/src/dist /opt/service/dist

ENV PORT=8080
EXPOSE 8080
CMD [ "npm", "run", "start:prod"]
