require 'rubygems'
require 'fileutils'
require 'sinatra'
require 'yaml'
require 'open3'
require 'bencode'
require 'uri'
require 'sha1'

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
	timestamp = Time.now.strftime("%s")
	datadir = File.join(Config[:datapath], timestamp)
 	fullname = File.join(Config[:datapath], timestamp, realname)
 	torrentname = File.join(Config[:torrentpath], timestamp + ".torrent")
 	FileUtils.mkdir_p datadir
 	FileUtils.mv tempname, fullname
 	system("transmission-create", fullname, "-o", torrentname)
 	hash = SHA1.hexdigest(File.read(torrentname).bdecode["info"].bencode)
 	system("transmission-remote", "-a", torrentname, "-w", datadir)
	uri = "magnet:?xt=urn:btih:#{hash}&dn=#{URI.encode(realname)}"
	surround "Success! Your URI is <br />
	<a href='#{uri}'>#{uri}</a>."
end