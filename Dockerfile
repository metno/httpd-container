ARG BASE_IMAGE=ubuntu:20.04
FROM $BASE_IMAGE

LABEL Trygve Aspenes <trygveas@met.no>

# let's copy a few of the settings from /etc/init.d/apache2
ENV APACHE_CONFDIR=/etc/apache2 \
    APACHE_ENVVARS=$APACHE_CONFDIR/envvars \
    # and then a few more from $APACHE_CONFDIR/envvars itself
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_RUN_DIR=/var/run/apache2\
    APACHE_PID_FILE=$APACHE_RUN_DIR/apache2.pid\
    APACHE_LOCK_DIR=/var/lock/apache2\
    APACHE_LOG_DIR=/var/log/apache2\
    LANG=C\
    MS_DEBUGLEVEL=5\
    MS_ERRORFILE=stderr\
    MAX_REQUESTS_PER_PROCESS=1000\
    IO_TIMEOUT=40\
    MIN_PROCESSES=1\
    MAX_PROCESSES=100\
    BUSY_TIMEOUT=300\
    IDLE_TIMEOUT=300

RUN apt-get update \
  && DEBIAN_FRONTEND="noninteractive" TZ="Europe/Oslo" apt-get -y install tzdata \
  && apt-get install -y apache2 apache2-dev python3-pip dumb-init \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && pip install mod_wsgi jinja2 \
  && mod_wsgi-express install-module > /etc/apache2/mods-available/wsgi.load \
  && a2enmod headers rewrite proxy_uwsgi proxy_http wsgi\
  && a2dismod -f auth_basic authn_file authn_core authz_host authz_user autoindex dir status \
  && rm /etc/apache2/mods-enabled/alias.conf \
  && mkdir -p $APACHE_RUN_DIR $APACHE_LOCK_DIR $APACHE_LOG_DIR \
  && ln -s ../../var/log/apache2 ${APACHE_CONFDIR}/logs \
  && find "$APACHE_CONFDIR" -type f -exec sed -ri ' \
       s!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g; \
       s!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g; \
       ' '{}' ';' \
  && sed -ri 's!<VirtualHost\s\*:80>!<VirtualHost *:8079>!g' /etc/apache2/sites-available/000-default.conf \
  && sed -ri 's!Listen\s80$!Listen 8079!g' /etc/apache2/ports.conf

EXPOSE 8079

CMD ["/usr/bin/dumb-init", "--", "apache2", "-DFOREGROUND"]
