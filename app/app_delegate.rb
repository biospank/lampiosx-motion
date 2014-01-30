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
        :capture  => /Incoming call|Chiamata in arrivo|Appel entrant|Llamada entrante|Eingehender Anruf/
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
      {:name => "JavaApplicationStub", 
        :ringing => false, 
        :capture => /ooVoo video call|chiamata Video ooVoo|Videochiamata ooVoo/
      }
    ]

    #@ua = /Universal|Universale|Bedienungs|universel/
    @ua = /Security|Sicurezza|Sicherheit|sécurité/
    
    # nome applicazione case insensitive
    @system_events = SBApplication.applicationWithBundleIdentifier("com.apple.systemevents")
    
    # NSTimer.scheduledTimerWithTimeInterval 3.0,
    #              target: self,
    #            selector: 'on_tick:',
    #            userInfo: nil,
    #             repeats: true

    @running = false

    Thread.new do
      locate_udp_server!
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

  # reset
  def on_check()
    if pi_alive?
      unless check_for_updates
        msg!
      end
    end
  end

  # def on_test()
  #   th_switch = Thread.new do
  #     system "ruby #{App.resources_path}/lampicli.rb notify_event"

  #     $?
  #   end

  #   # thread.value call thread.join
  #   unless th_switch.value.success?
  #     msg!
  #   end

  # end

  # def on_test()

  #   puts '------ beginning command ------'
    
  #   pi_ip = ''

  #   IO.popen("ruby #{App.resources_path}/udpcli.rb").each do |line|
  #     pi_ip = line
  #   end.close # Without close, you won't be able to access $?


  #   #puts system "ruby #{App.resources_path}/lampicli.rb get_pi_ip"

  #   puts '------ done with command ------'
     
  #   puts "The command's exit code was: #{$?.exitstatus}"
  #   puts 'Here is the output:'
  #   puts pi_ip

  # end

  # reset
  # def on_reset()
  #   th_reset = Thread.new do
  #     system "ruby #{App.resources_path}/lampicli.rb reset_event"

  #     $?
  #   end

  #   # thread.value call thread.join
  #   unless th_reset.value.success?
  #     msg!
  #   end

  # end

  # # check
  # def on_check()
  #   th_check = Thread.new do
  #     system "ruby #{App.resources_path}/lampicli.rb check_for_updates"

  #     $?
  #   end

  #   # thread.value call thread.join
  #   status = th_check.value.exitstatus

  #   case status
  #   when 1, 2
  #     msg!
  #   else
  #     if status > CURRENT_VERSION
  #       download_msg!("https://dl.dropboxusercontent.com/u/621599/work/Lamp-3.0-mavericks.dmg")
  #     else
  #       up_to_date_msg!
  #     end
  #   end

  # end

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

  def switch_lamp!()
    begin

      # puts "Querying http server..."
      BW::HTTP.get("http://#{pi_ip}:4567/lamp/osx") do |response|
        #p response.body.to_str
      end

      return true

    rescue Exception => ex
      puts ex.message
      return false
    end
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
        version = 31 #version_response.body.to_str

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
        if ringing? active_prc, prc[:capture]
          unless prc[:ringing]
            prc[:ringing] = true 
            return switch_lamp!
          end
        else
          prc[:ringing] = false
        end
      end
    end
  end

  def ringing?(current_prc, capture)
    if capture
      current_prc.windows.any? {|w| w.name =~ capture}
    else
      current_prc.windows.any? {|w| w.name.nil?}
    end
  end
  
  def on_tick(timer)
    unless @running
      Thread.new do
        @running = true
        check_processes()
        @running = false
      end
    end
  end

  def assistive_device_enabled?
    msg =<<-eomsg
Your system is not properly configured to run this app.
Please select the 'Enable access for assistive devices" checkbox
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
#      alert :message => msg, :icon => image(:file => "#{lib_path}/../resources/lamp.png")
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