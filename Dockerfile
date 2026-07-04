FROM nginx:alpine

# Copy static website assets to default Nginx serving directory
COPY index.html /usr/share/nginx/html/index.html

# Expose HTTP port 80
EXPOSE 80
