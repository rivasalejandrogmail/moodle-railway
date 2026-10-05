# Moodle for Railway — PHP 8.4
FROM erseco/alpine-moodle:latest

USER root

RUN apk add --no-cache su-exec

# Configurar el límite de procesos PHP.
# La variable se resuelve al iniciar el contenedor.
RUN sed -i 's/^pm\.max_children[[:space:]]*=.*/pm.max_children = ${PHP_FPM_MAX_CHILDREN}/' \
        /etc/php84/php-fpm.d/www.conf \
    && grep -q 'PHP_FPM_MAX_CHILDREN' /etc/php84/php-fpm.d/www.conf

# El archivo de origen conserva su ubicación en el repositorio.
# El destino corresponde a PHP 8.4.
COPY --chmod=0644 \
     rootfs/etc/php83/conf.d/zz-railway.ini \
     /etc/php84/conf.d/zz-railway.ini

COPY --chown=nobody:nobody --chmod=0755 \
     rootfs/etc/service/cron/run \
     /etc/service/cron/run

COPY --chown=nobody:nobody --chmod=0755 \
     rootfs/docker-entrypoint-init.d/50-railway.sh \
     /docker-entrypoint-init.d/50-railway.sh

COPY --chown=nobody:nobody --chmod=0755 \
     rootfs/docker-entrypoint-init.d/00-railway-db.sh \
     /docker-entrypoint-init.d/00-railway-db.sh

COPY --chmod=0644 \
     rootfs/usr/local/lib/railway-bootstrap-db.php \
     /usr/local/lib/railway-bootstrap-db.php

COPY --chmod=0644 \
     rootfs/usr/local/lib/railway-healthz.php \
     /usr/local/lib/railway-healthz.php

COPY --chown=nobody:nobody --chmod=0644 \
     rootfs/etc/nginx/server-conf.d/railway-health.conf \
     /etc/nginx/server-conf.d/railway-health.conf

COPY --chown=nobody:nobody --chmod=0644 \
     rootfs/etc/nginx/server-conf.d/railway-security.conf \
     /etc/nginx/server-conf.d/railway-security.conf

COPY --chmod=0755 \
     railway-entrypoint.sh \
     /railway-entrypoint.sh

# Preparar las dependencias de Moodle durante la compilación.
USER nobody
ENV COMPOSER_HOME=/tmp/.composer

RUN if [ -d /var/www/html/public ]; then \
        cd /var/www/html \
        && composer install --no-dev --no-interaction --classmap-authoritative \
        && rm -rf "$COMPOSER_HOME"; \
    fi

# El entrypoint ajusta los permisos y luego cambia a nobody.
USER root

ENV PHP_FPM_MAX_CHILDREN=16 \
    MOODLE_CRON_INTERVAL=60

ENTRYPOINT ["/railway-entrypoint.sh"]
