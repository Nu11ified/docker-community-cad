FROM webdevops/php-nginx:8.2-alpine

ENV CADVERSION=1.4.3.2

RUN apk add --no-cache oniguruma-dev postgresql-dev libxml2-dev \
    && docker-php-ext-install ctype fileinfo mbstring xml pdo pdo_mysql

RUN mkdir -p /app

RUN wget https://github.com/CommunityCAD/CommunityCAD/archive/refs/tags/v${CADVERSION}.zip \
    && unzip v${CADVERSION}.zip -d /tmp/communitycad

RUN ls -al /tmp/communitycad/

RUN mv /tmp/communitycad/CommunityCAD-${CADVERSION}/* /app

RUN ls -al /app

RUN chmod -R +x /app

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /app

COPY php.ini /opt/docker/etc/php/php.ini
COPY vhost.conf /opt/docker/etc/nginx/vhost.conf

COPY init.sh /opt/docker/provision/entrypoint.d/99-init.sh

RUN chmod +x /opt/docker/provision/entrypoint.d/99-init.sh

RUN ls -al /opt/docker/provision/entrypoint.d/

RUN chown -R application:application /app

RUN ls -al /app

RUN mkdir -p /app_installed

RUN touch /app_installed/.gitkeep 

EXPOSE 443
VOLUME ["/app_installed", "/vendor"]

