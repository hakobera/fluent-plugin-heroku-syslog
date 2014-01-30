# fluent-plugin-in-heroku-syslog

fluent plugin to drain heroku syslog.

[![Build Status](https://travis-ci.org/hakobera/fluent-plugin-heroku-syslog.png?branch=master)](https://travis-ci.org/hakobera/fluent-plugin-heroku-syslog)

## Component

### HerokuSyslogInput

Plugin to accept syslog input from [heroku syslog drains](https://devcenter.heroku.com/articles/logging#syslog-drains).

## Configuration

```
<source>
  type heroku_syslog
  bind 0.0.0.0
</source>
```

## Copyright

- Copyright
  - Copyright(C) 2014- Kazuyuki Honda (hakobera)
- License
  - Apache License, Version 2.0
