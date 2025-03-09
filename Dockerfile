FROM golang:1.22-bookworm AS builder

ARG APP_DIR=/app
ARG SNOWFLAKE_EXPORTER_ACCOUNT
ARG SNOWFLAKE_EXPORTER_USERNAME
ARG SNOWFLAKE_EXPORTER_PRIVATE_KEY_PATH
ARG SNOWFLAKE_EXPORTER_PRIVATE_KEY_PASSPHRASE
ARG SNOWFLAKE_EXPORTER_ROLE
ARG SNOWFLAKE_EXPORTER_WAREHOUSE

ENV SNOWFLAKE_EXPORTER_ACCOUNT=${SNOWFLAKE_EXPORTER_ACCOUNT}
ENV SNOWFLAKE_EXPORTER_USERNAME=${SNOWFLAKE_EXPORTER_USERNAME}
ENV SNOWFLAKE_EXPORTER_PRIVATE_KEY_PATH=${SNOWFLAKE_EXPORTER_PRIVATE_KEY_PATH}
ENV SNOWFLAKE_EXPORTER_PRIVATE_KEY_PASSPHRASE=${SNOWFLAKE_EXPORTER_PRIVATE_KEY_PASSPHRASE}
ENV SNOWFLAKE_EXPORTER_ROLE=${SNOWFLAKE_EXPORTER_ROLE}
ENV SNOWFLAKE_EXPORTER_WAREHOUSE=${SNOWFLAKE_EXPORTER_WAREHOUSE}

# Create a directory for the application
RUN mkdir -p "${APP_DIR}"
WORKDIR "${APP_DIR}"

COPY go.* *.txt .*.yml .yamllint errcheck_excludes.txt Makefile* ./
COPY cmd/ ./cmd/
COPY collector/ ./collector/
COPY mixin/ ./mixin/

RUN make precheck && \
    make style && \
    make check_license && \
    make build


FROM golang:1.22-bookworm AS release

ARG APP_DIR=/app
ARG SNOWFLAKE_EXPORTER_ACCOUNT
ARG SNOWFLAKE_EXPORTER_USERNAME
ARG SNOWFLAKE_EXPORTER_PRIVATE_KEY_PATH
ARG SNOWFLAKE_EXPORTER_PRIVATE_KEY_PASSPHRASE
ARG SNOWFLAKE_EXPORTER_ROLE
ARG SNOWFLAKE_EXPORTER_WAREHOUSE

ENV APP_DIR=${APP_DIR}
ENV SNOWFLAKE_EXPORTER_ACCOUNT=${SNOWFLAKE_EXPORTER_ACCOUNT}
ENV SNOWFLAKE_EXPORTER_USERNAME=${SNOWFLAKE_EXPORTER_USERNAME}
ENV SNOWFLAKE_EXPORTER_PRIVATE_KEY_PATH=${SNOWFLAKE_EXPORTER_PRIVATE_KEY_PATH}
ENV SNOWFLAKE_EXPORTER_PRIVATE_KEY_PASSPHRASE=${SNOWFLAKE_EXPORTER_PRIVATE_KEY_PASSPHRASE}
ENV SNOWFLAKE_EXPORTER_ROLE=${SNOWFLAKE_EXPORTER_ROLE}
ENV SNOWFLAKE_EXPORTER_WAREHOUSE=${SNOWFLAKE_EXPORTER_WAREHOUSE}

# Install required packages
RUN apt update \
    && apt install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates curl \
        git \
        tzdata \
        vim \
        wget \
    && update-ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    # Create a non-root user
    && addgroup --gid 1000 prometheus && \
    adduser  --uid 1000 --ingroup prometheus \
        --shell /bin/bash \
        --home /etc/prometheus \
        prometheus

# Create necessary directory structure for Kubernetes service account mount
RUN mkdir -p /run/secrets /var/run/secrets/kubernetes.io/serviceaccount && \
    chown -R prometheus:prometheus /run/secrets && \
    chmod -R 755 /run /var/run

# Create a directory for the application
RUN mkdir -p "${APP_DIR}"
WORKDIR "${APP_DIR}"
RUN chown -R prometheus:prometheus "${APP_DIR}"

COPY --from=builder --chown=1000:1000 "${APP_DIR}/snowflake-exporter" "${APP_DIR}/snowflake-exporter"

# Switch to non-root user
USER prometheus

# CMD ["sleep", "infinity"]
ENTRYPOINT ["/app/snowflake-exporter", "--web.listen-address=:9000", "--log.level=debug", "--exclude-deleted-tables"]

# Command to run the application
# ENTRYPOINT ["/usr/local/bin/snowflake-exporter", "--exclude-deleted-tables", "--log.level=debug" ]
