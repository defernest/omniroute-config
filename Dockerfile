ARG OMNIROUTE_IMAGE=diegosouzapw/omniroute:3.6.6

FROM ${OMNIROUTE_IMAGE} AS cli-builder

USER root

COPY scripts/install-cli-tools.sh /usr/local/bin/install-cli-tools.sh

RUN chmod 0755 /usr/local/bin/install-cli-tools.sh && \
    /usr/local/bin/install-cli-tools.sh

FROM ${OMNIROUTE_IMAGE}

USER root

COPY --from=cli-builder /opt/cli-bin/qodercli /usr/local/bin/qodercli
COPY --from=cli-builder /opt/cli-bin/kilo /usr/local/bin/kilo

RUN chmod 0755 /usr/local/bin/qodercli /usr/local/bin/kilo
