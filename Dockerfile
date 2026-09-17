FROM nginx:1.27-alpine

COPY site/index.html /usr/share/nginx/html/index.html

EXPOSE 80
