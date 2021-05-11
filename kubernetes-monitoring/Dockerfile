FROM nginx:alpine
LABEL maintainer="pitnub"
ARG nginx_uid=1001
ARG nginx_gid=1001
EXPOSE 80
RUN apk add shadow && usermod -u $nginx_uid -o nginx && groupmod -g $nginx_gid -o nginx \
 && sed -i 's/^}/    location = \/basic_status {\n        stub_status;\n    }\n}/' /etc/nginx/conf.d/default.conf
CMD ["nginx", "-g", "daemon off;"]
