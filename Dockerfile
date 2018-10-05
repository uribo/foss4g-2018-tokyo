FROM rocker/geospatial:3.5.1@sha256:3fa3ab6ca9025785709fd46e546af2b674c8fbb2a1bc286e3919b89f347513d6

RUN set -x && \
  apt-get update && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN set -x && \
  install2.r --error \
    estatapi \
    geofacet \
    geojsonio \
    here \ 
    jpmesh \
    jpndistrict \
    kokudosuuchi \
    lawn \
    stplanr \
    rayshader \
    rnaturalearth && \
  installGithub.r \
    "r-lib/rlang" \
    "ropenscilabs/rnaturalearthhires" \
    "uribo/jpmesh" \
    "uribo/jpndistrict" && \
  rm -rf /tmp/downloaded_packages/ /tmp/*.rds
