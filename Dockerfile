# Moodle for Railway.
#
# Upstream image: erseco/alpine-moodle (nginx + php-fpm 8.3 + runit, configured
# entirely through environment variables, with Moodle's own cron supervised in
# the same container). Everything below is Railway-specific and nothing else:
#
#   1. The image runs as `nobody`; a Railway volume arrives root-owned, so
#      Moodle cannot create its dataroot. An entrypoint takes ownership as root
#      and drops straight back to `nobody`.
#   2. Moodle 5.1+ has real Composer runtime dependencies and the image resolves
#      them on every boot. Baking them into a layer turns a multi-minute,
#      network-dependent start into a no-op.
#   3. php-fpm ships pm.max_children=100, sized for a host rather than for a
#      container quota, and opcache is untuned.
#   4. Moodle's cron is re-exec'd as fast as runit can restart it; upstream
#      Moodle asks for once a minute.
FROM erseco/alpine-moodle:latest

USER root

# su-exec is the smallest correct privilege dropper on Alpine: it execs, so the
# supervised process keeps PID 1's signal handling and Railway can drain it.
RUN apk add --no-cache su-exec

# Make the worker cap a variable. The image's entrypoint runs every php-fpm
# config file through envsubst, so ${PHP_FPM_MAX_CHILDREN} is resolved at boot
# and a Railway resize can be followed without rebuilding.
RUN php -v && find /etc -name www.conf -print
RUN sed -i 's/^pm\.max_children[[:space:]]*=.*/pm.max_children = ${PHP_FPM_MAX_CHILDREN}/' \
        /etc/php83/php-fpm.d/www.conf \
    && grep -q 'PHP_FPM_MAX_CHILDREN' /etc/php83/php-fpm.d/www.conf

COPY --chmod=0644 rootfs/etc/php83/conf.d/zz-railway.ini /etc/php83/conf.d/zz-railway.ini
COPY --chown=nobody:nobody --chmod=0755 rootfs/etc/service/cron/run /etc/service/cron/run
COPY --chown=nobody:nobody --chmod=0755 \
     rootfs/docker-entrypoint-init.d/50-railway.sh /docker-entrypoint-init.d/50-railway.sh
COPY --chown=nobody:nobody --chmod=0755 \
     rootfs/docker-entrypoint-init.d/00-railway-db.sh /docker-entrypoint-init.d/00-railway-db.sh
# Keep this in an existing directory: BuildKit applies COPY --chmod to any parent
# directory it has to create, so a new subdirectory would land without +x and the
# non-root runtime user could not traverse into it.
COPY --chmod=0644 rootfs/usr/local/lib/railway-bootstrap-db.php /usr/local/lib/railway-bootstrap-db.php
COPY --chmod=0644 rootfs/usr/local/lib/railway-healthz.php /usr/local/lib/railway-healthz.php
COPY --chown=nobody:nobody --chmod=0644 \
     rootfs/etc/nginx/server-conf.d/railway-health.conf /etc/nginx/server-conf.d/railway-health.conf
COPY --chown=nobody:nobody --chmod=0644 \
     rootfs/etc/nginx/server-conf.d/railway-security.conf /etc/nginx/server-conf.d/railway-security.conf
COPY --chmod=0755 railway-entrypoint.sh /railway-entrypoint.sh

# Resolve Moodle's Composer dependencies as the user that owns the tree, so the
# boot-time `composer install` the image performs finds everything in place.
# Moodle <5.1 has no public/ directory and no runtime dependencies.
USER nobody
ENV COMPOSER_HOME=/tmp/.composer
RUN if [ -d /var/www/html/public ]; then \
        cd /var/www/html \
        && composer install --no-dev --no-interaction --classmap-authoritative \
        && rm -rf "$COMPOSER_HOME"; \
    fi

# Root is required at start so the entrypoint can chown the mounted volume; it
# drops to `nobody` before anything Moodle owns is executed.
USER root

ENV PHP_FPM_MAX_CHILDREN=16 \
    MOODLE_CRON_INTERVAL=60

ENTRYPOINT ["/railway-entrypoint.sh"]
