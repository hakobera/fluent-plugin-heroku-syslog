require 'fluent/plugin/in_tcp'
require_relative 'logplex'

module Fluent
  class HerokuSyslogInput < TcpInput
    Plugin.register_input('heroku_syslog', self)

    config_param :port, :integer, :default => 5140
    config_param :format, :string, :default => Logplex::SYSLOG_REGEXP
  end
end
