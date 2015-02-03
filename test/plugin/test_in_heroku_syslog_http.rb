require 'helper'
require 'net/http'

class HerokuSyslogHttpInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  PORT = unused_port
  CONFIG = %[
    port #{PORT}
    bind 127.0.0.1
    body_size_limit 10m
    keepalive_timeout 5
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::HerokuSyslogHttpInput).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal PORT, d.instance.port
    assert_equal '127.0.0.1', d.instance.bind
    assert_equal 10*1024*1024, d.instance.body_size_limit
    assert_equal 5, d.instance.keepalive_timeout
  end

  def test_time_format
    d = create_driver

    tests = [
      {
          'msg' => "<13>1 2014-01-29T06:25:52.589365+00:00 host app web.1 foo",
          'expected' => 'foo',
          'expected_time' => Time.strptime('2014-01-29T06:25:52+00:00', '%Y-%m-%dT%H:%M:%S%z').to_i
      },
      {
          'msg' => "<13>1 2014-01-30T07:35:00.123456+09:00 host app web.1 bar",
          'expected' => 'bar',
          'expected_time' => Time.strptime('2014-01-30T07:35:00+09:00', '%Y-%m-%dT%H:%M:%S%z').to_i
      }
    ]

    tests.each do |msg|
      msg['msg'] = "#{msg['msg'].length} #{msg['msg']}"
    end

    d.expect_emit 'heroku', tests[0]['expected_time'], {
      "drain_id" => "d.fc6b856b-3332-4546-93de-7d0ee272c3bd",
      "ident"=>"app",
      "pid"=>"web.1",
      "message"=> "foo",
      "pri" => "13",
      "facility" => "user",
      "priority" => "notice"
    }

    d.expect_emit 'heroku', tests[1]['expected_time'], {
      "drain_id" => "d.fc6b856b-3332-4546-93de-7d0ee272c3bd",
      "ident"=>"app",
      "pid"=>"web.1",
      "message"=> "bar",
      "pri" => "13",
      "facility" => "user",
      "priority" => "notice"
    }

    d.run do
      res = post(tests)
      assert_equal "200", res.code
    end
  end

  def test_msg_size
    d = create_driver
    tests = create_test_case

    d.expect_emit 'heroku', tests[0]['expected_time'], {
      "drain_id" => "d.fc6b856b-3332-4546-93de-7d0ee272c3bd",
      "ident" => "app",
      "pid" => "web.1",
      "message" => "x" * 100,
      "pri" => "13",
      "facility" => "user",
      "priority" => "notice"
    }
    d.expect_emit 'heroku', tests[1]['expected_time'], {
      "drain_id" => "d.fc6b856b-3332-4546-93de-7d0ee272c3bd",
      "ident" => "app",
      "pid" => "web.1",
      "message" => "x" * 1024,
      "pri" => "13",
      "facility" => "user",
      "priority" => "notice"
    }

    d.run do
      res = post(tests)
      assert_equal "200", res.code
    end
  end

  def test_accept_matched_drain_id_multiple
    d = create_driver(CONFIG + "\ndrain_ids [\"abc\", \"d.fc6b856b-3332-4546-93de-7d0ee272c3bd\"]")
    tests = create_test_case

    d.expect_emit 'heroku', tests[0]['expected_time'], {
      "drain_id" => "d.fc6b856b-3332-4546-93de-7d0ee272c3bd",
      "ident" => "app",
      "pid" => "web.1",
      "message" => "x" * 100,
      "pri" => "13",
      "facility" => "user",
      "priority" => "notice"
    }
    d.expect_emit 'heroku', tests[1]['expected_time'], {
      "drain_id" => "d.fc6b856b-3332-4546-93de-7d0ee272c3bd",
      "ident" => "app",
      "pid" => "web.1",
      "message" => "x" * 1024,
      "pri" => "13",
      "facility" => "user",
      "priority" => "notice"
    }

    d.run do
      res = post(tests)
      assert_equal "200", res.code
    end
  end

  def test_ignore_unmatched_drain_id
    d = create_driver(CONFIG + "\ndrain_ids [\"abc\"]")
    tests = create_test_case

    d.run do
      res = post(tests)
      assert_equal "200", res.code
    end

    assert_equal(0, d.emits.length)
  end

  def create_test_case
    # actual syslog message has "\n"
    msgs = [
      {
        'msg' => '<13>1 2014-01-01T01:23:45.123456+00:00 host app web.1 ' + 'x' * 100,
        'expected' => 'x' * 100,
        'expected_time' => Time.parse("2014-01-01T01:23:45 UTC").to_i
      },
      {
        'msg' => '<13>1 2014-01-01T01:23:45.123456+00:00 host app web.1 ' + 'x' * 1024,
        'expected' => 'x' * 1024,
        'expected_time' => Time.parse("2014-01-01T01:23:45 UTC").to_i
      }
    ]

    msgs.each do |msg|
      msg['msg'] = "#{msg['msg'].length} #{msg['msg']}"
    end

    msgs
  end

  def post(messages)
    # https://github.com/heroku/logplex/blob/master/doc/README.http_drains.md
    http = Net::HTTP.new("127.0.0.1", PORT)
    req = Net::HTTP::Post.new('/heroku', {
      "Content-Type" => "application/logplex-1",
      "Logplex-Msg-Count" => messages.length.to_s,
      "Logplex-Frame-Id" => "09C557EAFCFB6CF2740EE62F62971098",
      "Logplex-Drain-Token" => "d.fc6b856b-3332-4546-93de-7d0ee272c3bd",
      "User-Agent" => "Logplex/v49"
    })
    req.body = messages.map {|msg| msg['msg']}.join("\n")
    http.request(req)
  end

end
