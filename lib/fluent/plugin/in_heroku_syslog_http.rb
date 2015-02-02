require 'fluent/plugin/in_http'
require_relative 'logplex'

module Fluent
  class HerokuSyslogHttpInput < HttpInput
    Plugin.register_input('heroku_syslog_http', self)

    config_param :format, :string, :default => Logplex::SYSLOG_REGEXP
    
    private

    def parse_params_with_parser(params)
      if content = params[EVENT_RECORD_PARAMETER]
        records = []
        messages = content.split("\n")
        messages.each do |msg|
          @parser.parse(msg) { |time, record|
            raise "Received event is not #{@format}: #{content}" if record.nil?
            record["time"] ||= time
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
