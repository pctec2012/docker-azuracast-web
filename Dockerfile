FROM ubuntu:bionic

# Set time zone
ENV TZ 'UTC'
RUN echo $TZ > /etc/timezone

# Avoid ERROR: invoke-rc.d: policy-rc.d denied execution of start.
RUN sed -i "s/^exit 101$/exit 0/" /usr/sbin/policy-rc.d

# Install essential packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -q -y --no-install-recommends apt-transport-https \
        curl wget tar software-properties-common sudo zip unzip git tzdata \
        php7.2-fpm php7.2-cli php7.2-gd \
        php7.2-curl php7.2-xml php7.2-zip php7.2-mysqlnd php7.2-mbstring php7.2-intl php7.2-redis

# Create azuracast user.
RUN adduser --home /var/azuracast --disabled-password --gecos "" azuracast \
    && mkdir -p /var/azuracast/www \
    && mkdir -p /var/azuracast/www_tmp \
    && chown -R azuracast:azuracast /var/azuracast \
    && chmod -R 777 /var/azuracast/www_tmp \
    && echo 'azuracast ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Install PHP 7.2
RUN mkdir -p /run/php
RUN touch /run/php/php7.2-fpm.pid

COPY ./php.ini /etc/php/7.2/fpm/conf.d/05-azuracast.ini
COPY ./php.ini /etc/php/7.2/cli/conf.d/05-azuracast.ini
COPY ./phpfpmpool.conf /etc/php/7.2/fpm/pool.d/www.conf

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# AzuraCast installer and update commands
COPY scripts/ /usr/local/bin
RUN chmod -R a+x /usr/local/bin

# Install Jobber
RUN curl -L https://github.com/dshearer/jobber/releases/download/v1.3.2/jobber_1.3.2-1_amd64_ubuntu16.deb > jobber.deb && \
    dpkg -i jobber.deb && \
    DEBIAN_FRONTEND=noninteractive apt-get install -f && \
    rm jobber.deb

ADD ./jobber.conf.yml /etc/jobber.conf
ADD ./jobber.yml /var/azuracast/.jobber

RUN chown azuracast:azuracast /var/azuracast/.jobber \
    && chmod 644 /var/azuracast/.jobber \
    && mkdir -p /var/jobber/1000 \
    && chown -R azuracast:azuracast /var/jobber/1000 

# Install Dockerize
ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# Clone repo and set up AzuraCast repo
USER azuracast

# Alert AzuraCast that it's running in Docker mode
RUN touch /var/azuracast/.docker

WORKDIR /var/azuracast/www

RUN wget https://github.com/AzuraCast/AzuraCast/archive/master.tar.gz \
    && tar -xzvf master.tar.gz --strip-components 1 \
    && rm master.tar.gz \
    && composer install -o --no-dev

VOLUME /var/azuracast/www

USER root

ENTRYPOINT ["dockerize","-wait","tcp://mariadb:3306","-wait","tcp://influxdb:8086","-timeout","10s"]

CMD ["/usr/sbin/php-fpm7.2", "-F", "--fpm-config", "/etc/php/7.2/fpm/php-fpm.conf", "-c", "/etc/php/7.2/fpm/"]