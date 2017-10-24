FROM ubuntu:xenial

# Install essential packages
RUN apt-get update && \
    apt-get install -q -y --no-install-recommends apt-transport-https curl wget tar \
        python-software-properties software-properties-common pwgen whois lnav sudo \
        cron zip unzip git

# Create azuracast user.
RUN adduser --home /var/azuracast --disabled-password --gecos "" azuracast \
    && chown -R azuracast:azuracast /var/azuracast \
    && echo 'azuracast ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \
    && mkdir -p /var/azuracast/www_tmp \
    && chmod -R 777 /var/azuracast/www_tmp

# Install PHP 7.1
RUN LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get install -q -y --no-install-recommends php7.1-fpm php7.1-cli php7.1-gd \
     php7.1-curl php7.1-xml php7.1-zip php7.1-mysqlnd php7.1-mbstring php7.1-intl php7.1-redis

RUN mkdir -p /run/php
RUN touch /run/php/php7.1-fpm.pid

COPY ./php.ini /etc/php/7.1/fpm/conf.d/05-azuracast.ini
COPY ./php.ini /etc/php/7.1/cli/conf.d/05-azuracast.ini
COPY ./phpfpmpool.conf /etc/php/7.1/fpm/pool.d/www.conf

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Set up locales
COPY locale.gen /etc/locale.gen

RUN apt-get update \
    && apt-get install -q -y locales gettext

# Set up crontab tasks
ADD crontab /etc/cron.d/azuracast-cron

RUN chmod 0644 /etc/cron.d/azuracast-cron \
    && touch /var/log/cron.log \
    && touch /var/azuracast/.docker

# Install PIP and Ansible
RUN add-apt-repository -y ppa:ansible/ansible && \
    apt-get update && \
    apt-get install -q -y --no-install-recommends python2.7 python-pip python-setuptools \
      python-wheel python-mysqldb ansible && \
    pip install --upgrade pip && \
    pip install influxdb

# AzuraCast installer and update commands
COPY scripts/ /usr/bin
RUN chmod a+x /usr/bin/azuracast_* && \
    chmod a+x /usr/bin/locale_*

CMD ["/usr/sbin/php-fpm7.1", "-F", "--fpm-config", "/etc/php/7.1/fpm/php-fpm.conf", "-c", "/etc/php/7.1/fpm/"]