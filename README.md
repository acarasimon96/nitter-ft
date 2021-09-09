# Nitter-FT

[![License](https://img.shields.io/github/license/acarasimon96/nitter-ft?style=flat)](#license)

**Nitter FT (Nitter Fast Track)** is a free and open source alternative Twitter front-end focused on privacy, implemented in [Nim](https://nim-lang.org/). \
Inspired by the [Invidious](https://github.com/iv-org/invidious) project.

This repository is a fork of the [original Nitter repository](https://github.com/zedeus/nitter) focused on serving new features, bug fixes, and code refractors at a rapid pace.

## Features

- No JavaScript or ads
- All requests go through the backend, so that your browser never talks to Twitter
- Prevents Twitter from tracking your IP or JavaScript fingerprint
- Uses Twitter's unofficial API (no rate limits or developer account required)
- Lightweight (for [@nim_lang](https://nitter.net/nim_lang), 60KB vs 784KB from twitter.com)
- RSS feeds
- Themes
- Clean, chronological home timeline of users you follow without a Twitter account
- Mobile support (responsive design)
- AGPLv3 licensed: no proprietary instances permitted

## Roadmap

- Embeds
- Archiving tweets/profiles
- Developer API

## Resources

See the [original repository's wiki](https://github.com/zedeus/nitter/wiki/) for [a list of instances](https://github.com/zedeus/nitter/wiki/Instances) and [browser extensions](https://github.com/zedeus/nitter/wiki/Extensions) maintained by the community.

## Why?

It's basically impossible to use Twitter without JavaScript enabled. If you try,
you're redirected to the legacy mobile version which is awful both functionally
and aesthetically. For privacy-minded folks, preventing JavaScript analytics and
potential IP-based tracking is important, but apart from using the legacy mobile
version and a VPN, it's impossible. This is is especially relevant now that Twitter
[removed the ability](https://www.eff.org/deeplinks/2020/04/twitter-removes-privacy-option-and-shows-why-we-need-strong-privacy-laws)
for users to control whether their data gets sent to advertisers.

Using an instance of Nitter (hosted on a VPS for example), you can browse
Twitter without JavaScript while retaining your privacy. In addition to
respecting your privacy, Nitter is on average around 15 times lighter than
Twitter, and in most cases serves pages faster (eg. timelines load 2-4x faster).

## Screenshot

![nitter](/screenshot.png)

## Installation

To compile Nitter you need a Nim installation, see
[nim-lang.org](https://nim-lang.org/install.html) for details. It is possible to
install it system-wide or in the user directory you create below.

To compile the scss files, you need to install `libsass`. On Ubuntu and Debian,
you can use `libsass-dev`.

Redis is required for caching and in the future for account info. It should be
available on most distros as `redis` or `redis-server` (Ubuntu/Debian).
Running it with the default config is fine, Nitter's default config is set to
use the default Redis port and localhost.

Here's how to create a `nitter` user, clone the repo, and build the project
along with the scss.

```bash
# useradd -m nitter
# su nitter
$ git clone https://github.com/zedeus/nitter
$ cd nitter
$ nimble build -d:release
$ nimble scss
$ mkdir ./tmp
$ cp nitter.example.conf nitter.conf
```

Set your hostname, port, HMAC key, https (must be correct for cookies), and
Redis info in `nitter.conf`. To run Redis, either run
`redis-server --daemonize yes`, or `systemctl enable --now redis` (or
redis-server depending on the distro). Run Nitter by executing `./nitter` or
using the systemd service below. You should run Nitter behind a reverse proxy
such as [Nginx](https://github.com/zedeus/nitter/wiki/Nginx) or Apache for
security reasons.

To build and run Nitter in Docker:
```bash
docker build -t nitter:latest .
docker run -v $(pwd)/nitter.conf:/src/nitter.conf -d -p 8080:8080 nitter:latest
```

A prebuilt Docker image is provided as well:
```bash
docker run -v $(pwd)/nitter.conf:/src/nitter.conf -d -p 8080:8080 zedeus/nitter:latest
```

Note the Docker commands expect a `nitter.conf` file in the directory you run them.

To run Nitter via systemd you can use this service file:

```ini
[Unit]
Description=Nitter (An alternative Twitter front-end)
After=syslog.target
After=network.target

[Service]
Type=simple

# set user and group
User=nitter
Group=nitter

# configure location
WorkingDirectory=/home/nitter/nitter
ExecStart=/home/nitter/nitter/nitter

Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
```

Then enable and run the service:
`systemctl enable --now nitter.service`

Nitter currently prints some errors to stdout, and there is no real logging
implemented. If you're running Nitter with systemd, you can check stdout like
this: `journalctl -u nitter.service` (add `--follow` to see just the last 15
lines). If you're running the Docker image, you can do this:
`docker logs --follow *nitter container id*`

## Contact

Feel free to join the [official Nitter Matrix channel](https://matrix.to/#/#nitter:matrix.org).

## Donate

Support the Nitter project with any of the following payment methods:

Liberapay: https://liberapay.com/zedeus \
Patreon: https://patreon.com/nitter \
BTC: bc1qp7q4qz0fgfvftm5hwz3vy284nue6jedt44kxya \
ETH: 0x66d84bc3fd031b62857ad18c62f1ba072b011925 \
LTC: ltc1qhsz5nxw6jw9rdtw9qssjeq2h8hqk2f85rdgpkr \
XMR: 42hKayRoEAw4D6G6t8mQHPJHQcXqofjFuVfavqKeNMNUZfeJLJAcNU19i1bGdDvcdN6romiSscWGWJCczFLe9RFhM3d1zpL
