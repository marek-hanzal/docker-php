FROM debian:jessie as build

# setup mandatory environment variables (optimized for PHP 5.3)
ENV \
    DEBIAN_FRONTEND=noninteractive \
    OPENSSL_VERSION=1.0.2g \
    PHP_INI_DIR=/usr/local/etc/php \
    PHP_VERSION=5.3.27

# install all required packages for PHP
RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates curl libpcre3 librecode0 libmysqlclient-dev libsqlite3-0 libxml2 git zip unzip python-pip \
        autoconf file g++ gcc libc-dev make pkg-config re2c xz-utils \
        autoconf2.13 libcurl4-openssl-dev libpcre3-dev libreadline6-dev librecode-dev libsqlite3-dev libssl-dev libxml2-dev

# install dumb-init as it goes from PIP (thus part of build, because pip with python is quite heavy)
RUN pip install dumb-init

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
		--with-curl \
		--with-openssl=/usr/local/ssl \
		--with-readline \
		--with-recode \
		--with-zlib \
	&& make -j"$(nproc)" \
	&& make install

RUN mkdir -p /usr/local/etc/php/conf.d/

# add all required files for the image (configurations, ...)
ADD rootfs/ /

RUN docker-php-ext-install pdo_mysql

# start a new, clean stage (without any heavy dependency)
FROM debian:jessie as runtime

ADD rootfs/ /

# install just required dependencies to keep the image as light as possible
RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates curl libpcre3 librecode0 libmysqlclient-dev libsqlite3-0 libxml2 git zip unzip

# take built binaries from build
COPY --from=build /usr/local/bin/php /usr/local/bin/php
COPY --from=build /usr/local/sbin/php-fpm /usr/local/sbin/php-fpm
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=build /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=build /usr/local/etc/ /usr/local/etc/
COPY --from=build /usr/local/bin/dumb-init /usr/local/bin/dumb-init
# take composer from official composer imsage
COPY --from=composer /usr/bin/composer /usr/local/bin/composer

# install plugin to make composer installs faaaaaaast
RUN composer global require hirak/prestissimo --no-plugins --no-scripts
# just see some info 'round (and also see if PHP binary is ok)
RUN \
    php -v && \
    php -m

# defualt work directory for an application
WORKDIR /opt/app

EXPOSE 9000

# define entrypoint for dumb-init and PHP-FPM as a default
ENTRYPOINT ["dumb-init", "--"]
CMD ["php-fpm"]
