FROM phusion/baseimage:latest
MAINTAINER Nathan Hopkins <natehop@gmail.com>

ENV DEBIAN_FRONTEND="noninteractive" \
    TERM="xterm" \
	PACKAGES="vim python-dev python-flup python-pip expect git sqlite3 libcairo2 libcairo2-dev python-cairo pkg-config nodejs" \
    REFRESHED_AT='2015-01-28'

RUN apt-get -q update && \
	apt-get -qy dist-upgrade && \

 	# Install Dependencies
 	apt-get -y --force-yes install ${PACKAGES} && \

 	# Cleanup
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

# Install python dependencies
RUN pip install django==1.5.12 \
 	django-tagging==0.3.1 \
 	twisted==11.1.0 \
 	txAMQP==0.6.2

# Install Graphite
RUN git clone -b 0.9.15 --depth 1 https://github.com/graphite-project/graphite-web.git /usr/local/src/graphite-web && \
	rm -rf /usr/local/src/graphite-web/.git
WORKDIR /usr/local/src/graphite-web
RUN python ./setup.py install
ADD scripts/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
ADD conf/graphite/ /opt/graphite/conf/

# Install Whisper
RUN git clone -b 0.9.15 --depth 1 https://github.com/graphite-project/whisper.git /usr/local/src/whisper && \
	rm -rf /usr/local/src/whisper/.git
WORKDIR /usr/local/src/whisper
RUN python ./setup.py install

# Install Carbon
RUN git clone -b 0.9.15 --depth 1 https://github.com/graphite-project/carbon.git /usr/local/src/carbon && \
	rm -rf /usr/local/src/carbon/.git
WORKDIR /usr/local/src/carbon
RUN python ./setup.py install

# Install Statsd
RUN git clone -b v0.7.2 --depth 1 https://github.com/etsy/statsd.git /opt/statsd && \
	rm -rf /opt/statsd/.git
ADD conf/statsd/config.js /opt/statsd/config.js

# Configure nginx
RUN rm /etc/nginx/sites-enabled/default
ADD conf/nginx/nginx.conf /etc/nginx/nginx.conf
ADD conf/nginx/graphite.conf /etc/nginx/sites-available/graphite.conf
RUN ln -s /etc/nginx/sites-available/graphite.conf /etc/nginx/sites-enabled/graphite.conf

# Init django admin
ADD scripts/django_admin_init.exp /usr/local/bin/django_admin_init.exp
RUN /usr/local/bin/django_admin_init.exp

# Logging support
RUN mkdir -p /var/log/carbon /var/log/graphite /var/log/nginx
ADD conf/logrotate /etc/logrotate.d/graphite
RUN chmod 644 /etc/logrotate.d/graphite

# Daemons
ADD daemons/carbon.sh /etc/service/carbon/run
ADD daemons/carbon-aggregator.sh /etc/service/carbon-aggregator/run
ADD daemons/graphite.sh /etc/service/graphite/run
ADD daemons/statsd.sh /etc/service/statsd/run
ADD daemons/nginx.sh /etc/service/nginx/run

# Defaults
EXPOSE 80:80 2003:2003/udp 2003-2004:2003-2004 2023-2024:2023-2024 8125:8125/udp 8126:8126
VOLUME ["/opt/graphite", "/etc/nginx", "/opt/statsd", "/etc/logrotate.d", "/var/log"]

WORKDIR /root

CMD ["/sbin/my_init"]