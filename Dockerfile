# Multi-stage hermetic build for VALIXIS AI PDF Maker Web
FROM ghcr.io/cirruslabs/flutter:stable AS build-stage

WORKDIR /app

# Cache package dependencies
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source and compile release web bundle
COPY . .
RUN flutter pub get && flutter build web --release

# Production minimal runtime
FROM nginx:alpine AS runtime

RUN rm -rf /usr/share/nginx/html/*
COPY --from=build-stage /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
