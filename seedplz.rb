require 'rubygems'
require 'fileutils'
require 'sinatra'
require 'yaml'
require 'open3'
require 'bencode'
require 'uri'
require 'digest/sha1'
require './common'

configure do
	Config = YAML.load_file('seedplz.yml')
	set :sessions, false
	set :port, Config[:port]
	set :bind, Config[:bind]
end

helpers do
	def surround(s)
		pre = "<html>
		<head>
		<link rel='stylesheet' type='text/css' href='/css.css'></link>
		<link rel='icon' type='image/png' href='http://dump.bitcheese.net/files/ytoxuki/favicon.png'></link>
		<meta httpequiv='Content-Type' content='text/html; charset=utf-8'></meta></head>
		<body>"
		post = "<hr />
		<p>SeedPlz the experimental torrent-seeding service. You upload a file (<60 MB), receive a magnet link and service seeds the torrent for at most 24 hours. Direct your feedback to <a href='mailto:voker57@gmail.com'>voker57@gmail.com</a></p></body></html>"
		pre + s + post
	end
end 

get "/css.css" do
	"body { 	background-color: #000000; 	color:white; } h1 { 	text-align: center; } .centered { 	text-align:center; } h2 { 	border-width:2px; 	border-color:#1C302C; /*	background-color: #3B2A5C; */} .text { 	border-width:2px; 	border-color:#1C302C; 	width:100%; } a:link { 	color:#00FF00; } a:visited { 	color:#00FF00; } a:hover { 	color:#55F9FF; }"
end

get '/' do
	txt = "<h1> Seed this plz </h1>
	<p>
	<form method='post' action='/upload' enctype='multipart/form-data'>
	<input type='file' name='file' size='50' />
	<input type='submit' />
	</form>
	</p>"
	surround txt
end

post '/upload' do
	begin
	tempname = params[:file][:tempfile].path
	realname = params[:file][:filename]
	if realname =~ %r&/|^\.\.&
		File.unlink tempname
		error "Baaad name"
	end
	if params[:file][:tempfile].size > Config[:maxsize]
		File.unlink tempname
		error "Too fat!"
	end
	tries = 0
	while `du -bs #{Config[:trpath]}/data`.split(/\s+/)[0].to_i > Config[:max_total_size] and tries < 10
		candidate = Dir.entries(Config[:trpath]+"/data").sort.reject{|v| v == "." or v == ".."}.first
		timestamp, hash = candidate.split(":")

		system("transmission-remote", *Seedplz.transargs, "-t", hash, "-rad")
		puts `find #{Config[:trpath]+"/data"} -type d -empty -exec rm -r {} \\;`
		tries += 1
	end
	if tries >= 10
		raise "Too much cleanup tries. Smth wrong."
	end
	
	
	
	timestamp = Time.now.strftime("%s")
	datadir = File.join(Config[:trpath], "data", timestamp)
	fullname = File.join(datadir, realname)
	FileUtils.mkdir_p datadir
 	FileUtils.mv tempname, fullname
 	torrentname = Dir::Tmpname.make_tmpname("seedplz", ".torrent")
	
	
	system("transmission-create", *Seedplz.transargs, fullname, "-o",  torrentname)
 	hash = Digest::SHA1.hexdigest(File.read(torrentname).bdecode["info"].bencode)
 	
	FileUtils.mv datadir, File.join(Config[:trpath], "data", timestamp + ":" + hash)
	
	datadir = File.join(Config[:trpath], "data", timestamp + ":" + hash)
 	
 	system("transmission-remote", *Seedplz.transargs, "-a", torrentname, "-w", datadir)
	
	uri = "magnet:?xt=urn:btih:#{hash}&dn=#{URI.encode(realname)}"
	surround "Success! Your URI is <br />
	<a href='#{uri}'>#{uri}</a>."
	rescue => e
		puts e
		puts e.backtrace.join("\n")
 		File.unlink params[:file][:tempfile].path if params[:file].is_a?(Hash) and params[:file][:tempfile].is_a?(Tempfile) and File.exists?(params[:file][:tempfile].path)
		File.unlink torrentname if defined? torrentname and torrentname != nil and File.exists? torrentname
		
		FileUtils.rm_r File.join(Config[:trpath], "data", timestamp) if defined? timestamp and timestamp != nil and File.exists?(File.join(Config[:trpath], "data", timestamp))

		error "Something bad happened. Sorry"
	end
end
