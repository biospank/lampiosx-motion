class AppDelegate
  include Menu

  CURRENT_VERSION = 30

  attr_accessor :pi_ip
  
  def applicationDidFinishLaunching(notification)
    createMenu()

    NSApp.terminate self unless assistive_device_enabled?

    #self.performSelectorInBackground('listen!', withObject: nil)
    
    qlisten = Dispatch::Queue.new("it.lampwireless.qlisten")
    
    qlisten.async do
      locate_udp_server!
    end
      
    qlisten.async do
      listen!
    end
  end

  def listen!
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

    init_bridge()
    init_switch()
    
    # run loop waiting for events every 3 seconds
    loop do
      sleep 3
      #puts "running..."
      check_processes()
    end
  end

  def check_processes
    @prcs.each do |prc|
      if(active_prc = (@system_events.processes.find { |p| p.name == prc[:name]}))
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
  
  def init_bridge()
    # nome applicazione case insensitive
    @system_events ||= SBApplication.applicationWithBundleIdentifier("com.apple.systemevents")
  end
    
  def init_switch()
    # keep http call on the current thread
    @switch_action = lambda do
      runLoop = NSRunLoop.currentRunLoop

      BW::HTTP.get("http://#{pi_ip}:4567/lamp/osx") do |response|
        #p response.body.to_str
      end
      
      runLoop.run
    end
  end
    
  def locate_udp_server!
    IO.popen("ruby #{App.resources_path}/udpcli.rb").each do |line|
      self.pi_ip = line.chomp
    end.close # Without close, you won't be able to access $?

    #self.pi_ip = "192.168.1.13" # test
    # puts $?.exitstatus
  end

  def switch_lamp!()
    #puts "switch_lamp!!"
    thread = NSThread.alloc.initWithTarget @switch_action, selector:"call", object:nil
    thread.start
  end
    
  def test_lamp!()
    d = EM::DefaultDeferrable.new
    
    d.errback {
      msg! unless @res
    }

    @res = nil
    
    # puts "Querying http server..."
    BW::HTTP.get("http://#{pi_ip}:4567/lamp/osx") do |response|
      @res = response.body
    end

    d.timeout 3
    
  end

  def reset_lamp!()
    d = EM::DefaultDeferrable.new
    
    d.errback {
      msg! unless @res
    }

    @res = nil
    
    # puts "Querying http server..."
    BW::HTTP.get("http://#{pi_ip}:4567/lamp/led/reset") do |response|
      @res = response.body
    end

    d.timeout 3
    
  end

  def check_for_updates
    d = EM::DefaultDeferrable.new
    
    d.errback {
      msg! unless @res
    }

    @res = nil
    
    # puts "Querying http server..."
    BW::HTTP.get("http://#{pi_ip}:4567/lamp/osx/version") do |version_response|
      if @res = version_response.body
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
    end

    d.timeout 3
    
  end
  
  def pi_alive?
    #puts "pi_ip: #{self.pi_ip}"

    unless pi_ip
      msg!
      return false
    end

    return true
  end

  # test
  def on_test()
    if pi_alive?
      test_lamp! 
    end
  end

  # reset
  def on_reset()
    if pi_alive?
      reset_lamp!
    end
  end

  # check
  def on_check()
    if pi_alive?
      check_for_updates
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
Please check connection and restart.
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

  def assistive_device_enabled?
    msg =<<-eomsg
Your system is not properly configured to run this app.
Please enable accessibility checkbox for Lamp
and trigger the script again to proceed.
    eomsg
    
    security_pane_regexp = /Security|Sicurezza|Sicherheit|Sécurité/
  
    init_bridge()

    if @system_events.UIElementsEnabled
      return true
    else
      system_preference = SBApplication.applicationWithBundleIdentifier("com.apple.systempreferences")
      system_preference.activate
      accessibility_pane = system_preference.panes.find { |p| p.name =~ security_pane_regexp}
      system_preference.setCurrentPane(accessibility_pane) if accessibility_pane
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