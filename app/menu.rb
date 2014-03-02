module Menu
  attr_accessor :status_menu

  def createMenu

    @status_menu = NSMenu.new

    @status_item = NSStatusBar.systemStatusBar.statusItemWithLength(NSSquareStatusItemLength)
    @status_item.setMenu(@status_menu)
    @status_item.setHighlightMode(true)
    image = NSImage.alloc.initByReferencingFile("#{App.resources_path}/lamp.png")
    image.size = [17, 17]
    @status_item.setImage(image)
    @status_menu.addItem createMenuItem("About #{App.name}", 'orderFrontStandardAboutPanel:')
    @status_menu.addItem NSMenuItem.separatorItem
    @status_menu.addItem createMenuItem("Test", 'on_test')
    @status_menu.addItem createMenuItem("Reset", 'on_reset')
#    @autostart = createMenuItem("Autostart", 'on_autostart')
#    @autostart.setState(true)
#    @status_menu.addItem @autostart
    @status_menu.addItem createMenuItem("Check for updates", 'on_check')
    @status_menu.addItem NSMenuItem.separatorItem
    @status_menu.addItem createMenuItem("Quit", 'terminate:')

  end

  def createMenuItem(name, action)
    NSMenuItem.alloc.initWithTitle(name, action: action, keyEquivalent: '')
  end

end
