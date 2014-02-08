# fluent-plugin-heroku-syslog, a plugin for [Fluentd](http://fluentd.org)

fluent plugin to drain heroku syslog.

[![Build Status](https://travis-ci.org/hakobera/fluent-plugin-heroku-syslog.png?branch=master)](https://travis-ci.org/hakobera/fluent-plugin-heroku-syslog)

## Component

### HerokuSyslogInput

Plugin to accept syslog input from [heroku syslog drains](https://devcenter.heroku.com/articles/logging#syslog-drains).

## Installation

Install with gem or fluent-gem command as:

```
# for fluentd
$ gem install fluent-plugin-heroku-syslog

# for td-agent
$ sudo /usr/lib64/fluent/ruby/bin/fluent-gem install fluent-plugin-heroku-syslog
```

## Configuration

```
<source>
  type heroku_syslog
  port 5140
  bind 0.0.0.0
  tag  heroku
</source>
```

## TODO

- Implement authentication logic or filter like HTTP basic auth.

## Copyright

- Copyright
  - Copyright(C) 2014- Kazuyuki Honda (hakobera)
- License
  - Apache License, Version 2.0
