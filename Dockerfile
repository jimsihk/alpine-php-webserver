ARG ARCH=
FROM ${ARCH}alpine:3.17.0

LABEL Maintainer="99048231+jimsihk@users.noreply.github.com" \
      Description="Lightweight container with NGINX & PHP-FPM based on Alpine Linux."

ARG PHP_V=8
ENV PHP_RUNTIME=php${PHP_V}
ENV PHP_FPM_RUNTIME=php-fpm${PHP_V}
# renovate: datasource=repology depName=alpine_edge/php8 versioning=loose
ENV PHP_VERSION="=8.0.27-r0"
# renovate: datasource=repology depName=alpine_3_16/php8-pecl-apcu versioning=loose
ARG PHP_PECL_APCU_VERSION="=5.1.21-r0"
# renovate: datasource=repology depName=alpine_3_16/php8-pecl-memcached versioning=loose
ARG PHP_PECL_MEMCACHED_VERSION="=3.2.0-r0"
# renovate: datasource=repology depName=alpine_3_16/php8-pecl-redis versioning=loose
ARG PHP_PECL_REDIS_VERSION="=5.3.7-r0"
# renovate: datasource=repology depName=alpine_edge/nginx versioning=loose
ARG NGINX_VERSION="=1.22.1-r0"
# renovate: datasource=repology depName=alpine_3_17/runit versioning=loose
ARG RUNIT_VERSION="=2.1.2-r6"
# renovate: datasource=repology depName=alpine_edge/curl versioning=loose
ARG CURL_VERSION="=7.87.0-r1"
# renovate: datasource=repology depName=alpine_3_17/gettext versioning=loose
ARG GETTEXT_VERSION="=0.21.1-r1"

# Install packages
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/main/" >> /etc/apk/repositories \
    && echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && echo "https://dl-cdn.alpinelinux.org/alpine/v3.16/main" >> /etc/apk/repositories \
    && echo "https://dl-cdn.alpinelinux.org/alpine/v3.16/community" >> /etc/apk/repositories \
    && apk --no-cache add \
        ${PHP_RUNTIME}${PHP_VERSION} \
        ${PHP_RUNTIME}-fpm${PHP_VERSION} \
        ${PHP_RUNTIME}-opcache${PHP_VERSION} \
        ${PHP_RUNTIME}-pecl-apcu${PHP_PECL_APCU_VERSION} \
        ${PHP_RUNTIME}-pecl-memcached${PHP_PECL_MEMCACHED_VERSION} \
        ${PHP_RUNTIME}-pecl-redis${PHP_PECL_REDIS_VERSION} \
        ${PHP_RUNTIME}-mysqli${PHP_VERSION} \
        ${PHP_RUNTIME}-pgsql${PHP_VERSION} \
        ${PHP_RUNTIME}-openssl${PHP_VERSION} \
        ${PHP_RUNTIME}-curl${PHP_VERSION} \
        # ${PHP_RUNTIME}-zlib \
        ${PHP_RUNTIME}-soap${PHP_VERSION} \
        ${PHP_RUNTIME}-xml${PHP_VERSION} \
        ${PHP_RUNTIME}-fileinfo${PHP_VERSION} \
        ${PHP_RUNTIME}-phar${PHP_VERSION} \
        ${PHP_RUNTIME}-intl${PHP_VERSION} \
        ${PHP_RUNTIME}-dom${PHP_VERSION} \
        ${PHP_RUNTIME}-xmlreader${PHP_VERSION} \
        ${PHP_RUNTIME}-ctype${PHP_VERSION} \
        ${PHP_RUNTIME}-session${PHP_VERSION} \
        ${PHP_RUNTIME}-iconv${PHP_VERSION} \
        ${PHP_RUNTIME}-tokenizer${PHP_VERSION} \
        ${PHP_RUNTIME}-zip${PHP_VERSION} \
        ${PHP_RUNTIME}-simplexml${PHP_VERSION} \
        ${PHP_RUNTIME}-mbstring${PHP_VERSION} \
        ${PHP_RUNTIME}-gd${PHP_VERSION} \
        nginx${NGINX_VERSION} \
        runit${RUNIT_VERSION} \
        curl${CURL_VERSION} \
        # ${PHP_RUNTIME}-pdo \
        # ${PHP_RUNTIME}-pdo_pgsql \
        # ${PHP_RUNTIME}-pdo_mysql \
        # ${PHP_RUNTIME}-pdo_sqlite \
        # ${PHP_RUNTIME}-bz2 \
# Create symlink so programs depending on `php` and `php-fpm` still function
    && if [ ! -L /usr/bin/php ]; then ln -s /usr/bin/${PHP_RUNTIME} /usr/bin/php; fi \
    && if [ ! -L /etc/php ]; then ln -s /etc/${PHP_RUNTIME} /etc/php; fi \
    && if [ ! -L /usr/sbin/php-fpm ]; then ln -s /usr/sbin/${PHP_FPM_RUNTIME} /usr/sbin/php-fpm; fi \
# Bring in gettext so we can get `envsubst`, then throw
# the rest away. To do this, we need to install `gettext`
# then move `envsubst` out of the way so `gettext` can
# be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext${GETTEXT_VERSION} \
    && mv /usr/bin/envsubst /tmp/ \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache $runDeps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
# Remove alpine cache
    && rm -rf /var/cache/apk/* \
# Remove default server definition
    && rm /etc/nginx/http.d/default.conf \
# Make sure files/folders needed by the processes are accessable when they run under the nobody user
    && chown -R nobody.nobody /run \
    && chown -R nobody.nobody /var/lib/nginx \
    && chown -R nobody.nobody /var/log/nginx

# Add configuration files
COPY --chown=nobody rootfs/ /

# Switch to use a non-root user from here on
USER nobody

# Add application
WORKDIR /var/www/html

# Expose the port nginx is reachable on
EXPOSE 8080

# Let runit start nginx & php-fpm
CMD [ "/bin/docker-entrypoint.sh" ]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping

ENV client_max_body_size=2M \
    clear_env=no \
    allow_url_fopen=On \
    allow_url_include=Off \
    display_errors=Off \
    file_uploads=On \
    max_execution_time=0 \
    max_input_time=-1 \
    max_input_vars=1000 \
    memory_limit=128M \
    post_max_size=8M \
    upload_max_filesize=2M \
    zlib.output_compression=On
