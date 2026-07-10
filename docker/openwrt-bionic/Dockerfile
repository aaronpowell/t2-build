FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      bison \
      build-essential \
      ca-certificates \
      curl \
      file \
      flex \
      gawk \
      gettext \
      git-core \
      less \
      libncurses5-dev \
      libncursesw5-dev \
      libssl1.0-dev \
      locales \
      patch \
      perl \
      python \
      python-dev \
      rsync \
      subversion \
      time \
      unzip \
      wget \
      xsltproc \
      zlib1g-dev \
 && locale-gen en_US.UTF-8 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /work

COPY build-entrypoint.sh /usr/local/bin/build-entrypoint.sh
RUN chmod +x /usr/local/bin/build-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/build-entrypoint.sh"]
CMD ["build"]
