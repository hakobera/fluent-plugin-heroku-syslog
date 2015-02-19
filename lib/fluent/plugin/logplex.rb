module Fluent
  module Logplex
    SYSLOG_REGEXP = '/^([0-9]+)\\s+\\<(?<pri>[0-9]+)\\>[0-9]* (?<time>[^ ]*) (?<drain_id>[^ ]*) (?<ident>[a-zA-Z0-9_\\/\\.\\-]*) (?<pid>[a-zA-Z0-9\\.]+)? *(?<message>.*)$/'
    SYSLOG_HTTP_REGEXP = '/^([0-9]+)\\s+\\<(?<pri>[0-9]+)\\>[0-9]* (?<time>[^ ]*) (?<drain_id>[^ ]*) (?<ident>[a-zA-Z0-9_\\/\\.\\-]*) (?<pid>[a-zA-Z0-9\\.]+)? *- *(?<message>.*)$/'

    FACILITY_MAP = {
      0   => 'kern',
      1   => 'user',
      2   => 'mail',
      3   => 'daemon',
      4   => 'auth',
      5   => 'syslog',
      6   => 'lpr',
      7   => 'news',
      8   => 'uucp',
      9   => 'cron',
      10  => 'authpriv',
      11  => 'ftp',
      12  => 'ntp',
      13  => 'audit',
      14  => 'alert',
      15  => 'at',
      16  => 'local0',
      17  => 'local1',
      18  => 'local2',
      19  => 'local3',
      20  => 'local4',
      21  => 'local5',
      22  => 'local6',
      23  => 'local7'
    }

    PRIORITY_MAP = {
      0  => 'emerg',
      1  => 'alert',
      2  => 'crit',
      3  => 'err',
      4  => 'warn',
      5  => 'notice',
      6  => 'info',
      7  => 'debug'
    }

    def parse_logplex(record, params=nil)
      pri = record['pri'].to_i
      record['facility'] = FACILITY_MAP[pri >> 3]
      record['priority'] = PRIORITY_MAP[pri & 0b111]

      if params
        record['drain_id'] = params['HTTP_LOGPLEX_DRAIN_TOKEN']
      end

      record
    end
  end
end
