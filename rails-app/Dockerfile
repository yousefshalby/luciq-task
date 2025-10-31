# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.3.4
FROM ruby:$RUBY_VERSION-slim

WORKDIR /rails-app

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    default-mysql-client \
    default-libmysqlclient-dev \
    build-essential \
    git \
    pkg-config \
    libjemalloc2 \
    libvips && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set environment variables
ENV BUNDLE_PATH="/usr/local/bundle" \
    PATH="/rails-app/bin:${PATH}"

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle config set frozen false && \
    bundle install

# Copy the rest of the application code
COPY . .

# Create directories and set permissions
RUN mkdir -p /rails-app/tmp/pids /rails-app/log && \
    chmod -R 755 /rails-app

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
