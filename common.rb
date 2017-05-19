module Seedplz
	def self.transargs
		ta = []
		if Seedplz.config[:transmission]
			if Seedplz.config[:transmission][:host] and Seedplz.config[:transmission][:port]
				ta << Seedplz.config[:transmission][:host] + ":" + Seedplz.config[:transmission][:port].to_s
			end
			if Seedplz.config[:transmission][:netrc]
				ta << "-N" << Seedplz.config[:transmission][:netrc]
			end
		end
		ta
	end
	
	def self.config=(v)
		@@config = v
	end
	
	def self.config
		@@config
	end
end
