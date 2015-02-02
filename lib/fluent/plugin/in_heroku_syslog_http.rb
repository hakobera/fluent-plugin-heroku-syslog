require 'fluent/plugin/in_http'
require_relative 'logplex'

module Fluent
  class HerokuSyslogHttpInput < HttpInput
    Plugin.register_input('heroku_syslog_http', self)
    include Logplex

    config_param :format, :string, :default => SYSLOG_REGEXP
    config_param :drain_ids, :array, :default => nil

    private

    def parse_params_with_parser(params)
      if content = params[EVENT_RECORD_PARAMETER]
        records = []
        messages = content.split("\n")
        messages.each do |msg|
          @parser.parse(msg) { |time, record|
            raise "Received event is not #{@format}: #{content}" if record.nil?

            record["time"] ||= time
            parse_logplex(record, params)
            unless @drain_ids.nil? || @drain_ids.include?(record['drain_id'])
              log.warn "drain_id not match: #{msg.inspect}"
              next
            end
            records << record
          }
        end
        return nil, records
      else
        raise "'#{EVENT_RECORD_PARAMETER}' parameter is required"
      end
    end
  end
end
