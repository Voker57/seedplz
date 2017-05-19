require 'rubygems'
require 'bencode'
require 'digest/sha1'
require 'yaml'

Config = YAML.load_file('seedplz.yml')

current_size = `du -bs #{Config[:trpath]}/data`.split(/\s+/)[0].to_i

if current_size > Config[:max_total_size]
	candidate = Dir.entries(Config[:trpath]+"/data").sort.reject{|v| v == "." or v == ".."}.first
	timestamp, hash = candidate.split(":")

	puts "transmission-remote -t #{hash} -rad"
	`transmission-remote -t #{hash} -rad`
end

