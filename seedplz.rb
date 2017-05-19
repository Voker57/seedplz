require 'rubygems'
require 'fileutils'
require 'sinatra'
require 'yaml'
require 'open3'
require 'bencode'
require 'uri'
require 'digest/sha1'

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
		<p>"+Config[:motd].to_s+"</p></body></html>"
		pre + s + post
	end
	
	def cleanup_temps(temps)
		temps.each do |tmp|
			next unless tmp.is_a? String
			if File.exists?(tmp)
				FileUtils.rm_r tmp
			end
		end
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
	temps = []
	begin
	temps << params[:file][:tempfile].path rescue nil
	tempname = params[:file][:tempfile].path
	realname = params[:file][:filename]
	if realname =~ %r&/|^\.\.&
		error "Baaad name"
	end
	if params[:file][:tempfile].size > Config[:maxsize]
		error "Too fat!"
	end
	
	tmpdir = Dir::Tmpname.make_tmpname("seedplz", "torrentdata")
	temps << tmpdir
	
	tcname = File.join(tmpdir, realname)
	
	FileUtils.mkdir_p tmpdir
	FileUtils.mv tempname, tcname
	
	
	torrentname = Dir::Tmpname.make_tmpname("seedplz", ".torrent")
	temps << torrentname
	
	system("transmission-create", *Seedplz.transargs, tcname, "-o",  torrentname) or raise "execution failed"
	
	hash = Digest::SHA1.hexdigest(File.read(torrentname).bdecode["info"].bencode)
	
	if !File.exists?("#{Config[:trpath]}/data/#{hash}")
	
		tries = 0
		while `du -bs #{Config[:trpath]}/data`.split(/\s+/)[0].to_i > Config[:max_total_size] and tries < 10
			candidate = Dir.glob(Config[:trpath]+"/data/*").sort_by {|f| File.stat(f).mtime}.first
			
			c_hash = candidate.split("/").last

			system("transmission-remote", *Seedplz.transargs, "-t", c_hash, "-rad") or raise "execution failed"
			puts `find #{Config[:trpath]+"/data"} -type d -empty -exec rm -r {} \\;`
			tries += 1
		end
		if tries >= 10
			raise "Too much cleanup tries. Smth wrong."
		end
		
		datadir = File.join(Config[:trpath], "data", hash)
		temps << datadir
		fullname = File.join(datadir, realname)
		
		FileUtils.mkdir_p datadir
		FileUtils.mv tcname, fullname
		
		system("transmission-remote", *Seedplz.transargs, "-a", torrentname, "-w", datadir) or raise "execution failed"
		temps.delete datadir
	
	end
	
	cleanup_temps(temps)
	
	uri = "magnet:?xt=urn:btih:#{hash}&dn=#{URI.encode(realname)}"
	surround "Success! Your URI is <br />
	<a href='#{uri}'>#{uri}</a>."
	
	rescue => e
		cleanup_temps(temps)
		puts e
		puts e.backtrace.join("\n")
		
		error "Something bad happened. Sorry"
	end
end
