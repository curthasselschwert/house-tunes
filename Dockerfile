FROM elixir:1.6.2-alpine

RUN mkdir -p /opt/app && \
    chmod -R 777 /opt/app && \
    apk update && \
    apk --no-cache --update add \
      git inotify-tools netcat-openbsd nodejs nodejs-npm coreutils && \
    rm -rf /var/cache/apk/*

ENV MIX_HOME=/opt/mix \
    HEX_HOME=/opt/hex \
    HOME=/opt/app

RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /opt/app
ARG MIX_ENV=dev
ENV MIX_ENV=$MIX_ENV

# Cache elixir deps
ADD mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

# Same with npm deps
ADD assets/package.json assets/
RUN cd assets && \
    npm install

ADD . .

# Run frontend build, compile, and digest assets
RUN cd assets/ && \
    npm run deploy && \
    cd - && \
    mix do compile, phx.digest

ENTRYPOINT ["/bin/ash", "-c"]
CMD ["mix phx.server --no-compile"]
