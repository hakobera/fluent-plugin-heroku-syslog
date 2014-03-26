require_relative 'logplex'

module Fluent
  class HerokuSyslogInput < Input
    include Fluent::Logplex
    Plugin.register_input('heroku_syslog', self)

    def initialize
      super
      require 'cool.io'
      require 'fluent/plugin/socket_util'
    end

    config_param :port, :integer, :default => 5140
    config_param :bind, :string, :default => '0.0.0.0'
    config_param :tag, :string

    def configure(conf)
      super
      configure_parser(conf)
    end

    def start
      if @parser
        callback = method(:receive_data_parser)
      else
        callback = method(:receive_data)
      end

      @loop = Coolio::Loop.new
      @handler = listen(callback)
      @loop.attach(@handler)

      @thread = Thread.new(&method(:run))
    end

    def shutdown
      @loop.watchers.each {|w| w.detach }
      @loop.stop
      @handler.close
      @thread.join
    end

    def run
      @loop.run
    rescue
      $log.error "unexpected error", :error=>$!.to_s
      $log.error_backtrace
    end

    private

    def listen(callback)
      $log.debug "listening heroku syslog socket on #{@bind}:#{@port}"
      Coolio::TCPServer.new(@bind, @port, TcpHandler, callback)
    end

    class TcpHandler < Coolio::Socket
      def initialize(io, on_message)
        super(io)
        if io.is_a?(TCPSocket)
          opt = [1, @timeout.to_i].pack('I!I!')  # { int l_onoff; int l_linger; }
          io.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, opt)
        end
        $log.trace { "accepted fluent socket object_id=#{self.object_id}" }
        @on_message = on_message
        @buffer = "".force_encoding('ASCII-8BIT')
      end

      def on_connect
      end

      def on_read(data)
        @buffer << data
        pos = 0

        # syslog family add "\n" to each message and this seems only way to split messages in tcp stream
        while i = @buffer.index("\n", pos)
          msg = @buffer[pos..i]
          valid, syslog = Fluent::Logplex.parse_message(msg)
          @on_message.call(syslog) if valid
          pos = i + 1
        end
        @buffer.slice!(0, pos) if pos > 0
      rescue => e
        $log.error "syslog error", :error => e, :error_class => e.class
        close
      end

      def on_close
        $log.trace { "closed fluent socket object_id=#{self.object_id}" }
      end
    end
  end
end
