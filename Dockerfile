FROM debian as build

# setup mandatory environment variables (optimized for PHP 5.3)
ENV \
    DEBIAN_FRONTEND=noninteractive \
    PHP_INI_DIR=/usr/local/etc/php \
    PHP_VERSION=7.4.1 \
    ENABLE_XDEBUG=false \
    ENABLE_OPCACHE=false

RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates curl xz-utils zip unzip python-pip bzip2 \
        autoconf file g++ gcc libc-dev make pkg-config re2c

# install dumb-init as it goes from PIP (thus part of build, because pip with python is quite heavy)
RUN pip install dumb-init

WORKDIR /usr/src
RUN \
    curl -SL "https://php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror" -o php.tar.xz && \
    curl -SL "https://php.net/get/php-$PHP_VERSION.tar.xz.asc/from/this/mirror" -o php.tar.xz.asc && \
    tar -Jxf php.tar.xz --strip-components=1

RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        libxml2-dev libssl-dev libsqlite3-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev libonig-dev \
        libpq-dev libreadline-dev libzip-dev libgmp-dev

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
		--with-zip \
		--enable-soap \
		--with-pear \
		--enable-phar \
		--with-gmp \
		--enable-intl \
		--enable-sockets \
		--enable-mbstring \
		--with-openssl=/usr/local/ssl \
		--with-readline \
		--with-zlib \
	&& make -j"$(nproc)" \
	&& make install

RUN mkdir -p /usr/local/etc/php/conf.d/

RUN chmod +x -R /usr/local/bin

RUN pecl install xdebug

# add all required files for the image (configurations, ...)
ADD rootfs/ /

# start a new, clean stage (without any heavy dependency)
FROM debian as runtime

ADD rootfs/ /

# install just required dependencies to keep the image as light as possible
RUN \
    apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates curl git \
        libreadline-dev libpq-dev libxml2-dev libonig-dev libsqlite3-dev libzip-dev

# take built binaries from build
COPY --from=build /usr/local/bin/php /usr/local/bin/php
COPY --from=build /usr/local/sbin/php-fpm /usr/local/sbin/php-fpm
COPY --from=build /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/
COPY --from=build /usr/local/lib/php/ /usr/local/lib/php/
COPY --from=build /usr/local/etc/ /usr/local/etc/
COPY --from=build /usr/local/bin/dumb-init /usr/local/bin/dumb-init
# take composer from official composer imsage
COPY --from=composer /usr/bin/composer /usr/local/bin/composer

# just see some info 'round (and also see if PHP binary is ok)
RUN \
    php -v && \
    php -m

# install plugin to make composer installs faaaaaaast
RUN composer global require hirak/prestissimo --no-plugins --no-scripts

# defualt work directory for an application
WORKDIR /var/www

EXPOSE 9000

# define entrypoint for dumb-init and PHP-FPM as a default
ENTRYPOINT ["dumb-init", "--"]
CMD ["php-fpm"]
