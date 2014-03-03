class AppDelegate
  include Menu

  CURRENT_VERSION = 30

  attr_accessor :pi_ip
  
  def applicationDidFinishLaunching(notification)
    #@app_name = NSBundle.mainBundle.infoDictionary['CFBundleDisplayName']

    start()

    NSApp.terminate self unless assistive_device_enabled?

  end

  def start
    createMenu()
    init_bridge()
  end

  def init_bridge
    # voip processes to check
    @prcs = [
      {:name => 'Camfrog', 
        :ringing => false, 
        :capture => nil
      },
      {:name => "Skype", 
        :ringing => false, 
        :capture  => /Incoming|Chiamata|Appel|Llamada|Eingehender/i
      }, 
      {:name => "firefox", 
        :ringing => false, 
        :capture  => /sta chiamando|is calling/
      }, 
      {:name => "safari", 
        :ringing => false, 
        :capture  => /sta chiamando|is calling/
      }, 
      {:name => "Google Chrome", 
        :ringing => false, 
        :capture  => /sta chiamando|is calling/
      }, 
      {:name => "ooVoo-Mac", 
        :ringing => false,
        :capture => lambda {|prc| (prc.windows.first ? (prc.windows.first.buttons.any? {|w| w.title =~ /Answer|Risposta|Réponse|Antwort/}) : false)}
      }
    ]

    #@ua = /Universal|Universale|Bedienungs|universel/
    @ua = /Security|Sicurezza|Sicherheit|Sécurité/
    
    # nome applicazione case insensitive
    @system_events = SBApplication.applicationWithBundleIdentifier("com.apple.systemevents")
    
#    timer = EM.add_periodic_timer 3.0 do
#      begin
#        unless @running
#          @running = true
#          check_processes()
#          @running = false
#        end      
#      rescue Exception => ex
#        @running = false
#        #puts ex.message
#      end
#    end
    
#    Dispatch::Queue.main do
#      EM.add_periodic_timer 3.0 do
#        begin
#          unless @running
#            @running = true
#            check_processes()
#            @running = false
#          end      
#        rescue Exception => ex
#          @running = false
#          #puts ex.message
#        end
#      end
#    end

    # keep http call on the current thread
    @switch_action = lambda do
      runLoop = NSRunLoop.currentRunLoop

      BW::HTTP.get("http://#{pi_ip}:4567/lamp/osx") do |response|
        #p response.body.to_str
      end
      
      runLoop.run
    end

#    # run loop waiting for events every 3 seconds
#    Thread.new do
#      loop do
#        sleep 3
#        begin
#          unless @running
#            puts "running..."
#            @running = true
#            check_processes()
#            @running = false
#          else
#            puts "not running..."
#          end      
#        rescue Exception => ex
#          @running = false
#          puts ex.message
#        end
#      end
#    end
#      
    Thread.new do
      locate_udp_server!
    end
      
    self.performSelectorInBackground('listen!', withObject: nil)

  end
    
  def listen!
    # run loop waiting for events every 3 seconds
    loop do
      sleep 3
      #puts "running..."
      check_processes()
    end
  end

  def locate_udp_server!
    IO.popen("ruby #{App.resources_path}/udpcli.rb").each do |line|
      self.pi_ip = line.chomp
    end.close # Without close, you won't be able to access $?

    # puts $?.exitstatus
  end

  def pi_alive?
    # puts "pi_ip: #{self.pi_ip}"

    unless pi_ip
      msg!
      return false
    end

    return true
  end

  # test
  def on_test()
    if pi_alive?
      unless switch_lamp! 
        msg!
      end
    end
  end

  # reset
  def on_reset()
    if pi_alive?
      unless reset_lamp!
        msg!
      end
    end
  end

  # check
  def on_check()
    if pi_alive?
      unless check_for_updates
        msg!
      end
    end
  end

  # autostart
#  def on_autostart()
#    
#    @autostart.setState((@autostart.state == 0 ? true : false))
#    puts @autostart.state
#    url = NSBundle.mainBundle.bundleURL.URLByAppendingPathComponent("Contents/Library/LoginItems/MyRubyMotionAppName-app-launcher.app") # path
#    LSRegisterURL(url, true)
#    unless SMLoginItemSetEnabled("com.your-name.MyRubyMotionAppName-app-launcher", enabled) # identifier
#      NSLog "SMLoginItemSetEnabled failed!"
#    end
#  end
  
  def msg!
    msg =<<-eomsg
Unable to find Lamp device: 
Please check connection and try again.
    eomsg

    alert :message => msg

  end

  def download_msg!(link)
    msg =<<-eomsg
A new version is available. 
Please download at: 
#{link}
    eomsg

    alert :message => msg

  end

  def up_to_date_msg!()
    msg =<<-eomsg
Lamp is up to date.
    eomsg

    alert :message => msg

  end

#  def switch_lamp!()
#    begin
#
#      puts 'switch_lamp..'
#      BW::HTTP.get("http://#{pi_ip}:4567/lamp/osx") do |response|
#        p response.body.to_str
#      end
#
#      return true
#
#    rescue Exception => ex
#      puts ex.message
#      return false
#    end
#  end

  def switch_lamp!()
    #puts "switch_lamp!!"
    thread = NSThread.alloc.initWithTarget @switch_action, selector:"call", object:nil
    thread.start
  end
    
  def reset_lamp!()
    begin

      # puts "Querying http server..."
      BW::HTTP.get("http://#{pi_ip}:4567/lamp/led/reset") do |response|
        #p response.body.to_str
      end

      return true

    rescue Exception => ex
      #puts ex.message
      return false
    end
  end

  def check_for_updates
    begin
      # puts "Querying http server..."
      BW::HTTP.get("http://#{pi_ip}:4567/lamp/osx/version") do |version_response|
        #p response.body.to_str
        version = version_response.body.to_str

        if version.to_i > CURRENT_VERSION
          download_msg!("www.lampwireless.it")
          # puts "Querying http server..."
          # BW::HTTP.get("http://#{pi_ip}:4567/lamp/osx/download") do |download_response|
          #   # download_msg!(download_response.body.to_str)
          # end

        else
          up_to_date_msg!
        end

      end

      return true

    rescue Exception => ex
      #puts ex.message
      return false
    end

  end
  
  def check_processes
    @prcs.each do |prc|
      if active_prc = @system_events.processes.find { |p| p.name == prc[:name]}
        if ringing?(active_prc, prc[:capture])
          #puts "ringing!!"
          unless prc[:ringing]
            #puts "prc ringing false"
            prc[:ringing] = true 
            switch_lamp! 
          end
        else
          prc[:ringing] = false
        end
      end
    end
  end

  def ringing?(current_prc, capture)
    if capture
      if capture.is_a? Regexp
        current_prc.windows.any? {|w| w.name =~ capture}
      else
        capture.call(current_prc)
      end
    else
      current_prc.windows.any? {|w| w.name.nil?}
    end
  end
  
#  def on_tick(timer)
#    unless @running
#      # Thread.new do
#        @running = true
#        check_processes()
#        @running = false
#      # end
#    end
#  end

  def assistive_device_enabled?
    msg =<<-eomsg
Your system is not properly configured to run this app.
Please enable accessibility checkbox for Lamp
and trigger the script again to proceed.
    eomsg
    
    if @system_events.UIElementsEnabled
      return true
    else
      system_preference = SBApplication.applicationWithBundleIdentifier("com.apple.systempreferences")
      system_preference.activate
      ua = system_preference.panes.find { |p| p.name =~ @ua}
      system_preference.setCurrentPane(ua) if ua
      alert :message => msg
      return false
    end

  end

  def alert(opts={})
    alert = NSAlert.new
    alert.setMessageText opts[:message]
    alert.setIcon(NSImage.alloc.initByReferencingFile("#{App.resources_path}/lamp.png"))
    alert.addButtonWithTitle "OK"
    alert.runModal
  end

end