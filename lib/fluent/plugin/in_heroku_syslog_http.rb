require 'fluent/plugin/in_http'
require_relative 'logplex'

module Fluent
  module Plugin
    class HerokuSyslogHttpInput < HttpInput
      Fluent::Plugin.register_input('heroku_syslog_http', self)
      include Logplex

      helpers :parser

      config_param :tag, :string
      config_param :drain_ids, :array, :default => nil

      config_section :parse do
        config_set_default :@type, 'regexp'
        config_set_default :expression, SYSLOG_HTTP_REGEXP
      end

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
end
