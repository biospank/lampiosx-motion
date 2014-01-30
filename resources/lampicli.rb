#!/usr/bin/env ruby

require 'thor'
require 'socket'
require 'timeout'
require 'net/http'
require 'uri'

module UDPClient
  LAMP_UDP_PORT = 12345

  def self.broadcast_to_potential_servers(content, udp_port)
    body = "reply_port=#{LAMP_UDP_PORT},content=#{content}"

    s = UDPSocket.new
    s.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
    #s.send(Marshal.dump(body), 0, '<broadcast>', udp_port)
    s.send(body, 0, '<broadcast>', udp_port)
    s.close
  end

  def self.start_server_listener(time_out=5, &code)
    Thread.fork do
      s = UDPSocket.new
      s.bind('0.0.0.0', LAMP_UDP_PORT)

      begin
        body, sender = timeout(time_out) { s.recvfrom(1024) }
        server_ip = sender[3]
        #data = Marshal.load(body)
        code.call(body, server_ip)
        s.close
      rescue Timeout::Error
        s.close
        raise
      end
    end
  end

  def self.query_server(content, server_udp_port, time_out=5, &code)
    thread = start_server_listener(time_out) do |data, server_ip|
      code.call(data, server_ip)
    end

    broadcast_to_potential_servers(content, server_udp_port)

    begin
      thread.join
    rescue Timeout::Error
      return false
    end

    true
  end

end

class Lampicli < Thor
  LAMP_SERVER_PORT = 1234

  desc "switch_lamp! PI_IP", "Send http request to lampi"
  def switch_lamp!(pi_ip)

    response = false

    begin

      #puts "Querying http server...#{pi_ip}"
      uri = URI.parse("http://#{pi_ip}:4567/lamp/win")

      response = Timeout::timeout(10) do
        http = Net::HTTP.new(uri.host, uri.port)
        http.request(Net::HTTP::Get.new(uri.request_uri))
      end

    rescue Exception => ex
      #puts "Error switch_lamp!: #{ex.message()}"
      response = false
    end

    return response
  end

  desc "reset_led! PI_IP", "Send http request to reset lampi led"
  def reset_led!(pi_ip)

    response = false

    begin

      #puts "Querying http server...#{pi_ip}"
      uri = URI.parse("http://#{pi_ip}:4567/lamp/led/reset")

      response = Timeout::timeout(10) do
        http = Net::HTTP.new(uri.host, uri.port)
        http.request(Net::HTTP::Get.new(uri.request_uri))
      end

    rescue Exception => ex
      #puts "Error switch_lamp!: #{ex.message()}"
      response = false
    end

    return response
  end

  desc "check! PI_IP", "Send http request to reset lampi led"
  def check!(pi_ip)

    response = false

    begin

      #puts "Querying http server...#{pi_ip}"
      uri = URI.parse("http://#{pi_ip}:4567/lamp/win/version")

      response = Timeout::timeout(10) do
        http = Net::HTTP.new(uri.host, uri.port)
        http.request(Net::HTTP::Get.new(uri.request_uri))
      end

    rescue Exception => ex
      #puts "Error switch_lamp!: #{ex.message()}"
      response = false
    end

    return response.body
  end

  desc "notify_event", "Notify the event to lampi"
  def notify_event
    #puts "Querying UDP server..."

    pi_ip = nil

    udp_ok = UDPClient.query_server("Hello", LAMP_SERVER_PORT) do |data, server_ip|
      #puts "Server answered:"
      #p(server_ip: server_ip, server_answer: data)
      pi_ip = server_ip
    end

    if udp_ok
      if invoke(:switch_lamp!, [pi_ip])
        exit(0)
      else
        exit(2) # no http connection
      end
    else
      exit(1) # no udp connection
    end

  end

  desc "reset_event", "Notify the event to lampi"
  def reset_event
    #puts "Querying UDP server..."

    pi_ip = nil

    udp_ok = UDPClient.query_server("Hello", LAMP_SERVER_PORT) do |data, server_ip|
      #puts "Server answered:"
      #p(server_ip: server_ip, server_answer: data)
      pi_ip = server_ip
    end

    if udp_ok
      if invoke(:reset_led!, [pi_ip])
        exit(0)
      else
        exit(2) # no http connection
      end
    else
      exit(1) # no udp connection
    end

  end

  desc "check_for_updates", "Check for updates to download"
  def check_for_updates
    #puts "Querying UDP server..."

    pi_ip = nil

    udp_ok = UDPClient.query_server("Hello", LAMP_SERVER_PORT) do |data, server_ip|
      #puts "Server answered:"
      #p(server_ip: server_ip, server_answer: data)
      pi_ip = server_ip
    end

    if udp_ok
      if version = invoke(:check!, [pi_ip])
        exit(version.to_i)
      else
        exit(2) # no http connection
      end
    else
      exit(1) # no udp connection
    end

  end

  desc "get_pi_ip", "Get ip from device"
  def get_pi_ip
    #puts "Querying UDP server..."

    pi_ip = nil

    udp_ok = UDPClient.query_server("Hello", LAMP_SERVER_PORT) do |data, server_ip|
      #puts "Server answered:"
      #p(server_ip: server_ip, server_answer: data)
      pi_ip = server_ip
    end


    if udp_ok
      puts pi_ip
      exit(pi_ip.to_i)
    else
      exit(1) # no udp connection
    end

  end

end

Lampicli.start(ARGV)