FROM caddy:2-alpine@sha256:5f5c8640aae01df9654968d946d8f1a56c497f1dd5c5cda4cf95ab7c14d58648

COPY Caddyfile /etc/caddy/Caddyfile
COPY _site /usr/share/caddy/

# Caddy writes its own state into these even with no TLS to manage, so they have
# to belong to the user that ends up running it.
RUN chown -R nobody:nobody /data /config

USER nobody:nobody

# Unprivileged, so above 1024. Traefik is told which port to use by a label in
# vps-docker rather than guessing.
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/ >/dev/null || exit 1
