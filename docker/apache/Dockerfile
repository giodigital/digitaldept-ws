FROM httpd:2.4-alpine

# Install required packages
RUN apk update && apk add --no-cache \
    apache2-utils \
    curl

# Enable required modules
RUN sed -i \
    -e 's/#LoadModule rewrite_module/LoadModule rewrite_module/' \
    -e 's/#LoadModule proxy_module/LoadModule proxy_module/' \
    -e 's/#LoadModule proxy_fcgi_module/LoadModule proxy_fcgi_module/' \
    -e 's/#LoadModule socache_shmcb_module/LoadModule socache_shmcb_module/' \
    /usr/local/apache2/conf/httpd.conf

# Copy configuration
COPY conf.d/vhost.conf /usr/local/apache2/conf/extra/vhost.conf
RUN echo "Include conf/extra/vhost.conf" >> /usr/local/apache2/conf/httpd.conf

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost/ || exit 1
