require 'fluent/plugin/in_syslog'
require_relative 'logplex'

module Fluent
  module Plugin
    class HerokuSyslogInput < SyslogInput
      Fluent::Plugin.register_input('heroku_syslog', self)
      include Logplex

      helpers :parser

      config_param :tag, :string
      config_param :drain_ids, :array, :default => nil
      config_param :protocol_type, :enum, list: [:tcp, :udp], default: :tcp

      config_section :parse do
        config_set_default :@type, 'regexp'
        config_set_default :expression, Logplex::SYSLOG_REGEXP
      end

      private

      def message_handler(data, sock)
        @parser.parse(data) do |time, record|
          unless time && record
            log.warn "failed to parse message", data: data
            return
          end

          unless @drain_ids.nil? || @drain_ids.include?(record['drain_id'])
            log.warn "drain_id not match: #{msg.inspect}"
            return
          end

          parse_logplex(record)

          record[@source_address_key] = sock.remote_addr if @source_address_key
          record[@source_hostname_key] = sock.remote_host if @source_hostname_key

          emit(@tag, time, record)
        end
      rescue => e
        log.error "invalid input", data: data, error: e
        log.error_backtrace
      end
    end
  end
end
