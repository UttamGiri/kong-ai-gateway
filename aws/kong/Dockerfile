# FROM kong/kong-gateway:3.9

# USER root

# COPY plugins/custom-header /usr/local/share/lua/5.1/kong/plugins/custom-header
# COPY kong.yml /kong/declarative/kong.yml

# RUN chown -R kong:kong \
#   /usr/local/share/lua/5.1/kong/plugins/custom-header \
#   /kong/declarative

# USER kong

# ENV KONG_DATABASE=off \
#     KONG_DECLARATIVE_CONFIG=/kong/declarative/kong.yml \
#     KONG_PLUGINS=bundled,custom-header \
#     KONG_PROXY_LISTEN=0.0.0.0:8000 \
#     KONG_ADMIN_LISTEN=0.0.0.0:8001 \
#     KONG_ADMIN_GUI_LISTEN=0.0.0.0:8002 \
#     KONG_PROXY_ACCESS_LOG=/dev/stdout \
#     KONG_ADMIN_ACCESS_LOG=/dev/stdout \
#     KONG_PROXY_ERROR_LOG=/dev/stderr \
#     KONG_ADMIN_ERROR_LOG=/dev/stderr \
#     KONG_LUA_PACKAGE_PATH=/usr/local/share/lua/5.1/?.lua;;

# EXPOSE 8000 8001 8002

#uncomment kong.yaml as well

FROM kong/kong-gateway:3.9
USER root

COPY plugins/custom-header /usr/local/share/lua/5.1/kong/plugins/custom-header
COPY plugins/custom-request-id /usr/local/share/lua/5.1/kong/plugins/custom-request-id
COPY kong.yml /kong/declarative/kong.yml

RUN chown -R kong:kong \
  /usr/local/share/lua/5.1/kong/plugins/custom-header \
  /usr/local/share/lua/5.1/kong/plugins/custom-request-id \
  /kong/declarative

USER kong

ENV KONG_DATABASE=off \
    KONG_DECLARATIVE_CONFIG=/kong/declarative/kong.yml \
    KONG_PLUGINS=bundled,custom-header,custom-request-id \
    KONG_PROXY_LISTEN=0.0.0.0:8000 \
    KONG_ADMIN_LISTEN=0.0.0.0:8001 \
    KONG_ADMIN_GUI_LISTEN=0.0.0.0:8002 \
    KONG_PROXY_ACCESS_LOG=/dev/stdout \
    KONG_ADMIN_ACCESS_LOG=/dev/stdout \
    KONG_PROXY_ERROR_LOG=/dev/stderr \
    KONG_ADMIN_ERROR_LOG=/dev/stderr \
    KONG_LUA_PACKAGE_PATH=/usr/local/share/lua/5.1/?.lua;;

EXPOSE 8000 8001 8002

