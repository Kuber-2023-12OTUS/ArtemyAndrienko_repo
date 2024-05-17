FROM nginx:1.25-bullseye

ENV DEBIAN_FRONTEND noninteractive
ENV TZ Europe/Moscow

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      apache2-utils \
 && rm -rf /var/lib/apt/lists/*

COPY nginx.default.conf /etc/nginx/
COPY docker-entrypoint.sh /tmp/

CMD ["/bin/bash", "/tmp/docker-entrypoint.sh"]