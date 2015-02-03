# fluent-plugin-heroku-syslog

[fluent](http://fluentd.org) plugin to drain heroku syslog.

[![Build Status](https://travis-ci.org/hakobera/fluent-plugin-heroku-syslog.png?branch=master)](https://travis-ci.org/hakobera/fluent-plugin-heroku-syslog)

## Installation

Install with gem or fluent-gem command as:

```
# for fluentd
$ gem install fluent-plugin-heroku-syslog

# for td-agent
$ sudo /usr/lib64/fluent/ruby/bin/fluent-gem install fluent-plugin-heroku-syslog
```

## Component

### HerokuSyslogInput

Plugin to accept syslog input from [heroku syslog drains](https://devcenter.heroku.com/articles/log-drains#syslog-drains).

#### Configuration

```
<source>
  type heroku_syslog
  port 5140
  bind 0.0.0.0
  tag  heroku
</source>
```

### HerokuSyslogHttpInput

Plugin to accept syslog input from [heroku http(s) drains](https://devcenter.heroku.com/articles/log-drains#http-s-drains).

#### Configuration

##### Basic

```
<source>
  type heroku_syslog_http
  port 9880
  bind 0.0.0.0
  tag  heroku
</source>
```

##### Filter by drain_ids

```
<source>
  type heroku_syslog_http
  port 9880
  bind 0.0.0.0
  tag  heroku
  drain_ids ["YOUR-HEROKU-DRAIN-ID"]
</source>
```

## Copyright

- Copyright
  - Copyright(C) 2014- Kazuyuki Honda (hakobera)
- License
  - Apache License, Version 2.0
