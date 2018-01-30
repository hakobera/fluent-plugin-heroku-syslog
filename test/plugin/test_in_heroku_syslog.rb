require 'helper'

class HerokuSyslogInputTest < Test::Unit::TestCase
  class << self
    def startup
      socket_manager_path = ServerEngine::SocketManager::Server.generate_path
      @server = ServerEngine::SocketManager::Server.open(socket_manager_path)
      ENV['SERVERENGINE_SOCKETMANAGER_PATH'] = socket_manager_path.to_s
    end

    def shutdown
      @server.close
    end
  end

  def setup
    Fluent::Test.setup
  end

  PORT = unused_port
  CONFIG = %[
    port #{PORT}
    bind 127.0.0.1
    tag heroku.syslog
  ]

  IPv6_CONFIG = %[
    port #{PORT}
    bind ::1
    tag heroku.syslog
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::Plugin::HerokuSyslogInput).configure(conf)
  end

  def test_configure
    configs = {'127.0.0.1' => CONFIG}
    configs.merge!('::1' => IPv6_CONFIG) if ipv6_enabled?

    configs.each_pair { |k, v|
      d = create_driver(v)
      assert_equal PORT, d.instance.port
      assert_equal k, d.instance.bind
    }
  end

  def test_configuring_drain_ids
    d = create_driver(CONFIG + %[drain_ids ["abc"]])
    assert_equal d.instance.drain_ids, ["abc"]
  end

  def test_time_format
    configs = {'127.0.0.1' => CONFIG}
    configs.merge!('::1' => IPv6_CONFIG) if ipv6_enabled?

    configs.each_pair { |k, v|
      d = create_driver(v)

      tests = [
        {
            'msg' => "92 <13>1 2014-01-29T06:25:52.589365+00:00 d.916a3e50-efa1-4754-aded-ffffffffffff app web.1 foo\n",
            'expected' => 'foo',
            'expected_time' => Time.strptime('2014-01-29T06:25:52+00:00', '%Y-%m-%dT%H:%M:%S%z').to_i
        },
        {
            'msg' => "92 <13>1 2014-01-30T07:35:00.123456+09:00 d.916a3e50-efa1-4754-aded-ffffffffffff app web.1 bar\n",
            'expected' => 'bar',
            'expected_time' => Time.strptime('2014-01-30T07:35:00+09:00', '%Y-%m-%dT%H:%M:%S%z').to_i
        }
      ]

      d.run do
        tests.each {|test|
          TCPSocket.open(k, PORT) do |s|
            s.send(test['msg'], 0)
          end
        }
        sleep 1
      end

      compare_test_result(d.emits, tests)
    }
  end

  def test_msg_size
    d = create_driver
    tests = create_test_case

    d.run do
      tests.each {|test|
        TCPSocket.open('127.0.0.1', PORT) do |s|
          s.send(test['msg'], 0)
        end
      }
      sleep 1
    end

    compare_test_result(d.emits, tests)
  end

  def test_msg_size_with_same_tcp_connection
    d = create_driver
    tests = create_test_case

    d.run do
      TCPSocket.open('127.0.0.1', PORT) do |s|
        tests.each {|test|
          s.send(test['msg'], 0)
        }
      end
      sleep 1
    end

    compare_test_result(d.emits, tests)
  end

  def test_accept_matched_drain_id
    d = create_driver(CONFIG + "\ndrain_ids [\"d.916a3e50-efa1-4754-aded-ffffffffffff\"]")
    tests = create_test_case

    d.run do
      TCPSocket.open('127.0.0.1', PORT) do |s|
        tests.each {|test|
          s.send(test['msg'], 0)
        }
      end
      sleep 1
    end

    compare_test_result(d.emits, tests)
  end

  def test_accept_matched_drain_id_multiple
    d = create_driver(CONFIG + "\ndrain_ids [\"abc\",\"d.916a3e50-efa1-4754-aded-ffffffffffff\"]")
    tests = create_test_case

    d.run do
      TCPSocket.open('127.0.0.1', PORT) do |s|
        tests.each {|test|
          s.send(test['msg'], 0)
        }
      end
      sleep 1
    end

    compare_test_result(d.emits, tests)
  end

  def test_ignore_unmatched_drain_id
    d = create_driver(CONFIG + "\ndrain_ids [\"abc\"]")
    tests = create_test_case

    d.run do
      TCPSocket.open('127.0.0.1', PORT) do |s|
        tests.each {|test|
          s.send(test['msg'], 0)
        }
      end
      sleep 1
    end

    assert_equal(0, d.emits.length)
  end

  def create_test_case
    # actual syslog message has "\n"
    msgs = [
      {'msg' => '<13>1 2014-01-01T01:23:45.123456+00:00 d.916a3e50-efa1-4754-aded-ffffffffffff app web.1 ' + 'x' * 100 + "\n", 'expected' => 'x' * 100},
      {'msg' => '<13>1 2014-01-01T01:23:45.123456+00:00 d.916a3e50-efa1-4754-aded-ffffffffffff app web.1 ' + 'x' * 1024 + "\n", 'expected' => 'x' * 1024},
    ]

    msgs.each do |msg|
      msg['msg'] = "#{msg['msg'].length} #{msg['msg']}"
    end

    msgs
  end

  def compare_test_result(emits, tests)
    assert_equal(tests.length, emits.length)
    emits.each_index {|i|
      assert_equal('heroku.syslog', emits[i][0])
      assert_equal(tests[i]['expected_time'], emits[i][1]) if tests[i]['expected_time']
      assert_equal(tests[i]['expected'], emits[i][2]['message']) if tests[i]['expected']
      assert_equal('d.916a3e50-efa1-4754-aded-ffffffffffff', emits[i][2]['drain_id'])
      assert_equal('app', emits[i][2]['ident'])
      assert_equal('web.1', emits[i][2]['pid'])
      assert_equal('user', emits[i][2]['facility'])
      assert_equal('notice', emits[i][2]['priority'])
    }
  end

end
