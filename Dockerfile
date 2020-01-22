FROM marekhanzal/buildbian as build

# setup mandatory environment variables
ENV \
    PHP_INI_DIR=/usr/local/etc/php \
    PHP_VERSION=7.2.26

WORKDIR /usr/src
RUN \
    curl -SL "https://php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror" | tar -Jx --strip-components=1

# download and build PHP
WORKDIR /usr/src
RUN \
    ./configure \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		--enable-fpm \
		--with-fpm-user=www-data \
		--with-fpm-group=www-data \
		--disable-cgi \
		--disable-phar \
		--with-pdo_mysql \
		--with-pdo_pgsql \
		--with-curl \
		--enable-bcmath \
		--with-bz2 \
		--enable-zip \
		--enable-soap \
		--with-pear \
		--enable-phar \
		--with-gmp \
		--enable-intl \
		--enable-sockets \
		--enable-mbstring \
		--with-openssl \
		--with-readline \
		--with-zlib \
		--with-libzip \
		--with-ldap \
	&& make -j"$(nproc)" \
	&& make install

RUN mkdir -p /usr/local/etc/php/conf.d/
RUN chmod +x -R /usr/local/bin

RUN pecl install xdebug

# add all required files for the image (configurations, ...)
ADD rootfs/build /

# take composer from official composer imsage
COPY --from=composer /usr/bin/composer /usr/local/bin/composer

# install plugin to make composer installs faaaaaaast
RUN composer global require hirak/prestissimo --no-plugins --no-scripts

# start a new, clean stage (without any heavy dependency)
FROM marekhanzal/debian as runtime

# install just required dependencies to keep the image as light as possible
RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        nginx openssh-server \
        libreadline-dev libpq-dev libxml2-dev libonig-dev libsqlite3-dev libzip-dev libldap2-dev

# take built binaries from build
COPY --from=build /usr/local/bin/php /usr/local/bin/php
COPY --from=build /usr/local/sbin/php-fpm /usr/local/sbin/php-fpm
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=build /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=build /usr/local/etc/ /usr/local/etc/
COPY --from=build /root/.composer/ /root/.composer/
# take composer from official composer imsage
COPY --from=composer /usr/bin/composer /usr/local/bin/composer

ADD rootfs/runtime /

RUN echo 'root:1234' | chpasswd
RUN chmod 600 -R /etc/ssh
RUN chmod 600 -R /root/.ssh
RUN chmod +x -R /usr/local/bin
RUN mkdir -p /var/run/sshd
RUN chmod 0755 -R /var/run/sshd

# just see some info 'round (and also see if PHP binary is ok)
RUN \
    php -v && \
    php -m

# defualt work directory for an application
WORKDIR /var/www
