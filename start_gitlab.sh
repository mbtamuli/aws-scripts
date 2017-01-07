#!/usr/bin/env bash

GITLAB_HOSTNAME=ec2-54-172-7-144.compute-1.amazonaws.com

docker run --detach \
  --hostname "$GITLAB_HOSTNAME" \
  --publish 443:443 --publish 80:80 --publish 5555:22 \
  --name gitlab \
  --volume /srv/gitlab/config:/etc/gitlab \
  --volume /srv/gitlab/logs:/var/log/gitlab \
  --volume /srv/gitlab/data:/var/opt/gitlab \
  gitlab/gitlab-ce:latest
