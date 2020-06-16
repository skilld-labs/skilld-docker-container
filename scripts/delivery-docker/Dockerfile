FROM scratch

ARG BUILD_DATE
ARG BUILD_NAME
ARG BUILD_DESC
ARG BUILD_URL
ARG BUILD_MAINTAINER

LABEL org.label-schema.build-date=$BUILD_DATE \
	org.label-schema.name=$BUILD_NAME \
	org.label-schema.description=$BUILD_DESC \
	org.label-schema.vcs-url=$BUILD_URL \
	maintainer=$BUILD_MAINTAINER

WORKDIR src
COPY . .


