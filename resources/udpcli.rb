require 'socket'
require 'timeout'

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

class Udpcli
  LAMP_SERVER_PORT = 1234

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
      exit(0)
    else
      exit(1) # no udp connection
    end

  end

end

Udpcli.new.get_pi_ip()
