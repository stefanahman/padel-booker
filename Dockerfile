ARG RUBY_VERSION=2.7

FROM ruby:${RUBY_VERSION} as build

WORKDIR /usr/src/app

COPY Gemfile* ./

RUN gem install bundler

RUN bundle config set without 'development test'
RUN bundle install -j 4

FROM ruby:${RUBY_VERSION}-slim as runtime

ENV DEBIAN_FRONTEND noninteractive
ENV CHROMIUM_DRIVER_VERSION 80.0.3987.16
ENV CHROME_VERSION 80.0.3987.116-1

# Install dependencies & Chrome
RUN apt-get update && apt-get -y --no-install-recommends install zlib1g-dev liblzma-dev wget xvfb unzip libnss3 nodejs gnupg2 \
 && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -  \
 && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list \
 && apt-get update && apt-get -y --no-install-recommends install google-chrome-stable=$CHROME_VERSION \
 && rm -rf /var/lib/apt/lists/*

# Install Chrome driver
RUN wget -O /tmp/chromedriver.zip http://chromedriver.storage.googleapis.com/$CHROMIUM_DRIVER_VERSION/chromedriver_linux64.zip \
    && unzip /tmp/chromedriver.zip chromedriver -d /usr/bin/ \
    && rm /tmp/chromedriver.zip \
    && chmod ugo+rx /usr/bin/chromedriver \
    && apt-mark hold google-chrome-stable

RUN mkdir -p /usr/src/app && \
    groupadd -g 999 app && \
    useradd -r -u 999 -g app app -d /usr/src/app && \
    chown app:app /usr/src/app

WORKDIR /usr/src/app

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY . .

RUN chown -R app:app /usr/src/app
USER app

CMD ["ruby", "lib/padel-booker.rb"]
