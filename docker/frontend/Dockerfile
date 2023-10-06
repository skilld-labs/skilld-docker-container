FROM node:lts-alpine3.10

RUN mkdir -p /frontend/themes

ENV BASE_THEMES_PATH /frontend/themes

COPY frontend-manager /usr/bin

RUN chmod +x /usr/bin/frontend-manager
