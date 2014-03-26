module Fluent
  module Logplex
    OCTET_COUNTING_REGEXP = /^([0-9]+)\s+(.*)/
    SYSLOG_REGEXP = /^\<([0-9]+)\>[0-9]*(.*)/
    SYSLOG_ALL_REGEXP = /^\<(?<pri>[0-9]+)\>[0-9]* (?<time>[^ ]*) (?<drain_id>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*) (?<pid>[a-zA-Z0-9\.]+)? *(?<message>.*)$/
    TIME_FORMAT = "%Y-%m-%dT%H:%M:%S%z"

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

    def configure_parser(conf)
      parser = TextParser.new
      if parser.configure(conf, false)
        @parser = parser
      else
        @parser = nil
        @time_parser = TextParser::TimeParser.new(TIME_FORMAT)
      end
    end

    def receive_data_parser(data)
      m = SYSLOG_REGEXP.match(data)
      unless m
        $log.debug "invalid syslog message: #{data.dump}"
        return
      end
      pri = m[1].to_i
      text = m[2]

      time, record = @parser.parse(text)
      unless time && record
        return
      end

      emit(pri, time, record)

    rescue
      $log.warn data.dump, :error=>$!.to_s
      $log.debug_backtrace
    end

    def receive_data(data)
      m = SYSLOG_ALL_REGEXP.match(data)
      unless m
        $log.debug "invalid syslog message", :data=>data
        return
      end

      pri = nil
      time = nil
      record = {}

      m.names.each {|name|
        if value = m[name]
          case name
          when "pri"
            pri = value.to_i
          when "time"
            time = @time_parser.parse(value.gsub(/ +/, ' ').gsub(/\.[0-9]+/, ''))
          else
            record[name] = value
          end
        end
      }

      time ||= Engine.now

      emit(pri, time, record)

    rescue
      $log.warn data.dump, :error=>$!.to_s
      $log.debug_backtrace
    end

    def emit(pri, time, record)
      facility = FACILITY_MAP[pri >> 3]
      priority = PRIORITY_MAP[pri & 0b111]

      tag = "#{@tag}.#{facility}.#{priority}"

      Engine.emit(tag, time, record)
    rescue => e
      $log.error "syslog failed to emit", :error => e.to_s, :error_class => e.class.to_s, :tag => tag, :record => Yajl.dump(record)
    end

    def self.parse_message(msg)
      # Support Octet Counting 
      # https://tools.ietf.org/html/rfc6587#section-3.4.1
      m = OCTET_COUNTING_REGEXP.match(msg)
      valid = true
      syslog = nil
      offset = msg.end_with?("\n") ? 1 : 0
      if m
        msg_len = m[1].to_i
        syslog = m[2]

        if msg_len != (syslog.length + offset)
          $log.debug "invalid syslog message length", :expected => msg_len, :actual => syslog.length + offset, :data => msg
          valid = false
        end
      end
      [valid, syslog]
    end
  end
end
