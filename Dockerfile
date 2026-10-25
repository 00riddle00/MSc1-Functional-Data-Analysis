# vim: set ft=dockerfile tw=88 nu ai et ts=4 sw=4:

FROM docker.io/rocker/r-ver:4.5.3

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gfortran git cmake pkg-config curl \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libfreetype6-dev libpng-dev libtiff-dev libjpeg-dev \
    libwebp-dev libicu-dev libuv1-dev libgmp-dev \
    libx11-dev pandoc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/fda

COPY renv.lock .Rprofile ./
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json

ENV RENV_PATHS_LIBRARY=/opt/fda-library

# Restore stringr first to avoid the selectr/stringr dependency-order issue.
RUN Rscript -e 'renv::restore(packages = "stringr", prompt = FALSE)'

RUN Rscript -e 'renv::restore(prompt = FALSE)'

# The full restore can repair future to 1.80.0; restore the locked 1.70.0.
RUN Rscript -e 'renv::restore(packages = "future", prompt = FALSE)'
