# CI test image for unit/lint/type tests
FROM node:10-alpine as ci

RUN apk add --update bash

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . ./
RUN npx lerna bootstrap
RUN npm run build

# Image used to build the features required to run the browser maze-runner tests
FROM ci as browser-feature-builder

WORKDIR /app
RUN npm pack --verbose packages/js/
RUN npm pack --verbose packages/browser/
RUN npm pack --verbose packages/node/
RUN npm pack --verbose packages/plugin-angular/
RUN npm pack --verbose packages/plugin-react/
RUN npm pack --verbose packages/plugin-vue/

WORKDIR packages/browser/features/fixtures
RUN npm install --no-package-lock --no-save ../../../../bugsnag-browser-*.tgz
RUN npm install --no-package-lock --no-save ../../../../bugsnag-plugin-react-*.tgz
RUN npm install --no-package-lock --no-save ../../../../bugsnag-plugin-vue-*.tgz
WORKDIR plugin_angular/ng
RUN npm install --no-package-lock --no-save \
  ../../../../../../bugsnag-plugin-angular-*.tgz  \
  ../../../../../../bugsnag-node-*.tgz \
  ../../../../../../bugsnag-browser-*.tgz \
  ../../../../../../bugsnag-js-*.tgz

# install the dependencies and build each fixture
WORKDIR /app/packages/browser/features/fixtures
RUN find . -path */package.json -type f -mindepth 2 -maxdepth 3 | \
  xargs -I % bash -c 'cd `dirname %` && npm install --no-package-lock && npm run build'

# Image used to build the features required to run the node maze-runner tests
FROM ci as node-feature-builder
WORKDIR /app
RUN npm pack --verbose packages/node/
RUN npm pack --verbose packages/plugin-express/
RUN npm pack --verbose packages/plugin-koa/
RUN npm pack --verbose packages/plugin-restify/

# The maze-runner browser tests
FROM 855461928731.dkr.ecr.us-west-1.amazonaws.com/maze-runner:browser-cli as browser-maze-runner
RUN apk add --no-cache ruby-dev build-base libffi-dev curl-dev
ENV GLIBC_VERSION 2.23-r3

RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub \
  && wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/glibc-$GLIBC_VERSION.apk" \
  && apk --no-cache add "glibc-$GLIBC_VERSION.apk" \
  && rm "glibc-$GLIBC_VERSION.apk" \
  && wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/glibc-bin-$GLIBC_VERSION.apk" \
  && apk --no-cache add "glibc-bin-$GLIBC_VERSION.apk" \
  && rm "glibc-bin-$GLIBC_VERSION.apk" \
  && wget "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$GLIBC_VERSION/glibc-i18n-$GLIBC_VERSION.apk" \
  && apk --no-cache add "glibc-i18n-$GLIBC_VERSION.apk" \
  && rm "glibc-i18n-$GLIBC_VERSION.apk"

RUN wget -q https://www.browserstack.com/browserstack-local/BrowserStackLocal-linux-x64.zip \
  && unzip BrowserStackLocal-linux-x64.zip \
  && rm BrowserStackLocal-linux-x64.zip

COPY --from=browser-feature-builder /app/packages/browser /app/packages/browser/
WORKDIR /app/packages/browser

# The maze-runner node tests
FROM 855461928731.dkr.ecr.us-west-1.amazonaws.com/maze-runner:node-cli as node-maze-runner
WORKDIR /app/
COPY packages/node/ .
COPY --from=node-feature-builder /app/*.tgz ./
RUN for d in features/fixtures/*/; do cp /app/*.tgz "$d"; done
