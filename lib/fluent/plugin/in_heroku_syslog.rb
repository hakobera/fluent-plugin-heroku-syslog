module Fluent
  class HerokuSyslogInput < Input
    Plugin.register_input('heroku_syslog', self)

    OCTET_COUNTING_REGEXP = /^([0-9]+)\s+(.*)/
    SYSLOG_REGEXP = /^\<([0-9]+)\>[0-9]*(.*)/
    SYSLOG_ALL_REGEXP = /^\<(?<pri>[0-9]+)\>[0-9]* (?<time>[^ ]*) (?<host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*) (?<pid>[a-zA-Z0-9\.]+)? *(?<message>.*)$/
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

      parser = TextParser.new
      if parser.configure(conf, false)
        @parser = parser
      else
        @parser = nil
        @time_parser = TextParser::TimeParser.new(TIME_FORMAT)
      end
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

    protected
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

    private

    def listen(callback)
      $log.debug "listening heroku syslog socket on #{@bind}:#{@port}"
      Coolio::TCPServer.new(@bind, @port, TcpHandler, callback)
    end

    def emit(pri, time, record)
      facility = FACILITY_MAP[pri >> 3]
      priority = PRIORITY_MAP[pri & 0b111]

      tag = "#{@tag}.#{facility}.#{priority}"

      Engine.emit(tag, time, record)
    rescue => e
      $log.error "syslog failed to emit", :error => e.to_s, :error_class => e.class.to_s, :tag => tag, :record => Yajl.dump(record)
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
          # Support Octet Counting 
          # https://tools.ietf.org/html/rfc6587#section-3.4.1
          m = OCTET_COUNTING_REGEXP.match(msg)
          if m
            msg_len = m[1].to_i
            msg = m[2]

            if msg_len != msg.length
              $log.debug "invalid syslog message length", :data => msg
              next
            end
          end
          @on_message.call(msg)
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
