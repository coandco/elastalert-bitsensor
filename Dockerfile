FROM alpine:latest as py-ea
ARG ELASTALERT_VERSION=1334b611fdd7adf39991a1b0b11689568d612690
ENV ELASTALERT_VERSION=${ELASTALERT_VERSION}
# URL from which to download Elastalert.
ARG ELASTALERT_URL=https://github.com/Yelp/elastalert/archive/$ELASTALERT_VERSION.zip
ENV ELASTALERT_URL=${ELASTALERT_URL}
# Elastalert home directory full path.
ENV ELASTALERT_HOME /opt/elastalert

WORKDIR /opt

RUN apk add --update --no-cache ca-certificates openssl-dev openssl python3-dev python3 py3-pip py3-yaml libffi-dev gcc musl-dev wget && \
# Download and unpack Elastalert.
    wget -O elastalert.zip "${ELASTALERT_URL}" && \
    unzip elastalert.zip && \
    rm elastalert.zip && \
    mv e* "${ELASTALERT_HOME}"

WORKDIR "${ELASTALERT_HOME}"

# Install Elastalert.
# With the latest hash we no longer need to monkey with package versions
RUN python3 setup.py install

FROM node:alpine
LABEL maintainer="BitSensor <dev@bitsensor.io>"
# Set timezone for this container
ENV TZ Etc/UTC

RUN apk add --update --no-cache curl tzdata python3 make libmagic && \
    ln -s /usr/bin/python3 /usr/bin/python

COPY --from=py-ea /usr/lib/python3.8/site-packages /usr/lib/python3.8/site-packages
COPY --from=py-ea --chown=node:node /opt/elastalert /opt/elastalert
COPY --from=py-ea /usr/bin/elastalert* /usr/bin/

USER node
COPY --chown=node:node package.json /opt/elastalert-server/package.json
COPY --chown=node:node index.js /opt/elastalert-server/index.js
COPY --chown=node:node .babelrc /opt/elastalert-server/.babelrc

WORKDIR /opt/elastalert-server

RUN npm install --production --quiet
COPY --chown=node:node scripts/ /opt/elastalert-server/scripts
COPY --chown=node:node src/ /opt/elastalert-server/src

COPY --chown=node:node config/elastalert.yaml /opt/elastalert/config.yaml
COPY --chown=node:node config/elastalert-test.yaml /opt/elastalert/config-test.yaml
COPY --chown=node:node config/config.json config/config.json
COPY --chown=node:node rule_templates/ /opt/elastalert/rule_templates
COPY --chown=node:node elastalert_modules/ /opt/elastalert/elastalert_modules

# Add default rules directory
# No longer need to run separate set-permission step with COPY --chown=node:node
RUN mkdir -p /opt/elastalert/rules/ /opt/elastalert/server_data/tests/

# Several modules trigger a SyntaxWarning with Python 3.8 and squawk
ENV PYTHONWARNINGS ignore

EXPOSE 3030
ENTRYPOINT ["npm", "start"]
