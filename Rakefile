# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/osx'
require 'bubble-wrap/core'
require 'bubble-wrap/http'
#require 'rubygems'
#require 'motion-cocoapods'

begin
  require 'bundler'
  Bundler.require
rescue LoadError
end

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'Lamp'
  app.identifier = 'lampwireless.it'
  app.version = '3.0 mavericks'
  app.info_plist['LSUIElement'] = true
  app.frameworks << "ScriptingBridge"

  # pods
  # app.pods do
  #   pod 'CocoaAsyncSocket'
  # end
end

# Track and specify files and their mutual dependencies within the :motion Bundler group
#MotionBundler.setup do |app|
  # app.require "socket"
  # app.require 'net/http'
  # app.require 'uri'

#end