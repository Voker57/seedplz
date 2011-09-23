require 'rubygems'
require 'daemons'

pwd = Dir.pwd
Daemons.run_proc('seedplz.rb', {:dir_mode => :normal, :dir => "."}) do
Dir.chdir(pwd)
ENV["RACK_ENV"] = "production"
exec "ruby seedplz.rb"
end