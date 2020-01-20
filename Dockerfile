FROM debian:jessie as build

# setup mandatory environment variables (optimized for PHP 5.3)
ENV \
    DEBIAN_FRONTEND=noninteractive \
    OPENSSL_VERSION=1.0.2u \
    PHP_INI_DIR=/usr/local/etc/php \
    PHP_VERSION=5.3.29 \
    ENABLE_XDEBUG=false

# install all required packages for PHP
RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates curl libpcre3 librecode0 libmysqlclient-dev libsqlite3-0 libxml2 git zip unzip bzip2 \
        autoconf file g++ gcc libc-dev make pkg-config re2c xz-utils \
        autoconf2.13 libcurl4-openssl-dev libpcre3-dev libreadline6-dev librecode-dev libsqlite3-dev libssl-dev libxml2-dev \
        libbz2-dev libpq-dev libicu-dev libgmp-dev libmcrypt-dev

RUN ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h

# OpenSSL required for PHP build
WORKDIR /tmp/openssl
RUN \
    curl -sL "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz && \
    curl -sL "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz.asc" -o openssl.tar.gz.asc
RUN tar -xzf openssl.tar.gz --strip-components=1
RUN \
    ./config && \
    make depend && \
    make -j"$(nproc)" && \
    make install

# download and build PHP
WORKDIR /usr/src
RUN \
    curl -SL "https://php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror" -o php.tar.xz && \
    curl -SL "https://php.net/get/php-$PHP_VERSION.tar.xz.asc/from/this/mirror" -o php.tar.xz.asc
RUN tar -Jxf php.tar.xz --strip-components=1
RUN \
    ./configure \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		--enable-fpm \
		--with-fpm-user=www-data \
		--with-fpm-group=www-data \
		--disable-cgi \
		--enable-mysqlnd \
		--with-mysql \
		--with-pdo_mysql \
		--enable-pdo_mysql \
		--with-pdo_pgsql \
		--enable-pdo_pgsql \
		--with-curl \
		--with-bcmath \
		--enable-bcmath \
		--with-bz2 \
		--enable-bz2 \
		--with-zip \
		--enable-zip \
		--with-soap \
		--enable-soap \
		--with-sockets \
		--enable-sockets \
		--with-mbstring \
		--enable-mbstring \
		--with-openssl=/usr/local/ssl \
		--with-readline \
		--with-recode \
		--with-zlib \
	&& make -j"$(nproc)" \
	&& make install

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

RUN mkdir -p /usr/local/etc/php/conf.d/

# add all required files for the image (configurations, ...)
ADD rootfs/build /

RUN chmod +x -R /usr/local/bin

RUN pecl install xdebug-2.2.7

# extensions which are hard to compile with PHP
RUN docker-php-ext-install \
    gmp intl

# install plugin to make composer installs faaaaaaast
RUN composer global require hirak/prestissimo --no-plugins --no-scripts

# start a new, clean stage (without any heavy dependency)
FROM debian:jessie as runtime

# install just required dependencies to keep the image as light as possible
RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates curl nginx openssh-server supervisor \
        libpcre3 librecode0 libmysqlclient-dev libsqlite3-0 libxml2 git zip unzip bzip2 \
        libpq-dev libicu-dev libgmp-dev libmcrypt-dev

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

EXPOSE 9000

CMD ["supervisord", "-c", "/etc/supervisord.conf"]
