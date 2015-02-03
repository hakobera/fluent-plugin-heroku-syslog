require 'fluent/plugin/in_tcp'
require_relative 'logplex'

module Fluent
  class HerokuSyslogInput < TcpInput
    Plugin.register_input('heroku_syslog', self)
    include Logplex

    config_param :format, :string, :default => SYSLOG_REGEXP
    config_param :drain_ids, :array, :default => nil

    private

    def on_message(msg, addr)
      @parser.parse(msg) { |time, record|
        unless time && record
          log.warn "pattern not match: #{msg.inspect}"
          return
        end

        unless @drain_ids.nil? || @drain_ids.include?(record['drain_id'])
          log.warn "drain_id not match: #{msg.inspect}"
          return
        end

        record[@source_host_key] = addr[3] if @source_host_key
        parse_logplex(record)
        router.emit(@tag, time, record)
      }
    rescue => e
      log.error msg.dump, :error => e, :error_class => e.class, :host => addr[3]
      log.error_backtrace
    end
  end
end
