# skilld-docker-container

---

* [Overview](#overview)
* [Instructions](#instructions)

## Overview

## Instructions

Supported PHP versions: 7.x and 5.6.x.

1\. Install docker for <a href="https://docs.docker.com/engine/installation/" target="_blank">Linux</a>, <a href="https://docs.docker.com/engine/installation/mac" target="_blank">Mac OS X</a> or <a href="https://docs.docker.com/engine/installation/windows" target="_blank">Windows</a>. __For Mac and Windows make sure you're installing native docker app version 1.12, not docker toolbox.__

For Linux additionally install <a href="https://docs.docker.com/compose/install/" target="_blank">docker compose</a>

2\. Copy __.env.default__ to __.env__

 2.1. Set _COMPOSE_PROJECT_NAME_, _PROFILE_NAME_, _THEME_NAME_ variables.
 2.2. Change _PHP_IMAGE_ in case you need another one.

3\. Run `make`
