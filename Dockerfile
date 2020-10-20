FROM rocker/geospatial:4.0.3

# Extra R packages
RUN install2.r drake here janitor skimr googleCloudStorageR

# Rstudio interface preferences
COPY rstudio-prefs.json /home/rstudio/.config/rstudio/rstudio-prefs.json
