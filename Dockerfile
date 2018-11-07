FROM rocker/geospatial:3.5.1@sha256:0552a064a1dd334c6b273c2e7c7df4614555d0dcdd3fc3b6710fb6eb8e1b8d3f

RUN set -x && \
  apt-get update && \
  apt-get install -y --no-install-recommends\
    curl && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN set -x && \
  : "rust environment" && \
  curl -sf -L https://static.rust-lang.org/rustup.sh | sh && \
  git clone https://github.com/rust-lang/cargo && \
  cd cargo && \
  cargo build --release && \
  cargo install gifski

RUN set -x && \
  install2.r --error \
    cartogram \
    CAST \
    colormap \
    estatapi \
    geofacet \
    geojsonio \
    getlandsat \
    here \ 
    jpmesh \
    jpndistrict \
    kokudosuuchi \
    lawn \
    mapdeck \
    mlr \
    osmdata \
    sperrorest \
    stplanr \
    randomForest \
    rayshader \
    rnaturalearth \
    rnoaa \
    tmap && \
  installGithub.r \
    "Nowosad/spDataLarge" \
    "r-lib/rlang" \
    "ropenscilabs/rnaturalearthhires" \
    "rvalavi/blockCV" \
    "thomasp85/gganimate" \
    "uribo/jpmesh" \
    "uribo/jpndistrict" \
    "uribo/jpnp" && \
  Rscript -e 'devtools::install_git("https://gitlab.com/uribo/jmastats")' && \
  Rscript -e 'webshot::install_phantomjs()' && \
  rm -rf /tmp/downloaded_packages/ /tmp/*.rds
  
ENV PATH $PATH:/root/bin/phantomjs

RUN set -x && \
  mv /root/bin/phantomjs /usr/local/bin/phantomjs
