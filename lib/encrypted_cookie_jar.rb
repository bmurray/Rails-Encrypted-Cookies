require 'openssl'
module ActionDispatch
class Cookies
class CookieJar
	def encrypted
		@encrypted ||= EncryptedCookieJar.new(self, @secret)
	end
end #Cookiejar
class PermanentCookieJar
	def encrypted
		@encrypted ||= EncryptedCookieJar.new(self, @secret)
	end
	def [](name)
		@parent_jar[name]
	end
end
class EncryptedCookieJar < SignedCookieJar
	MAX_COOKIE_SIZE = 4096
	KEY_LENGTH = 32
	SECRET_MIN_LENGTH = 30 # Characters
	ENCRYPTION_KEY_SIZE = 16
	OPTIONS = { :safe_mode => false }
	class << self
		attr_accessor :data_cipher_type
		def encryption_key=(k)
			OPTIONS[:encryption_key] = k
		end
		def safe_mode=(k)
			OPTIONS[:safe_mode] = k
		end
	end
        self.data_cipher_type = "aes-256-cfb".freeze

	def initialize(parent_jar, secret)
		ensure_encryption_key_secure(OPTIONS[:encryption_key])
		@data_cipher = OpenSSL::Cipher::Cipher.new(EncryptedCookieJar.data_cipher_type)
		@encryption_key = OPTIONS[:encryption_key].freeze
		super(parent_jar, secret)
	end
	def []=(key, options)
		if options.is_a?(Hash)
			options.symbolize_keys!
			options[:value] = encrypt(options[:value])
		else
			options = { :value => encrypt(options) }
		end
		raise CookieOverflow if options[:value].size > MAX_COOKIE_SIZE
		super(key, options)
	end
	def [](key)
		v = super(key)
		return nil if v.nil?
		if ! v.is_a?(String) && ! OPTIONS[:safe_mode]
			raise ArgumentError, "Cookie not encrypted! Maybe you are using this " +
					"as a session handler and changed from CookieStore " + 
					"to EncryptedCookieStore? To use legacy sessions, use " + 
					"ActionDispatch::Cookies::EncryptedCookieJar.safe_mode = false "
		end
		return decrypt(v) if v
		return v
	end
	def method_missing(method, *arguments, &block)
		@parent_jar.send(method, *arguments, &block)
	end

	private
        def ensure_encryption_key_secure(encryption_key)
                if encryption_key.blank?
                        raise ArgumentError, "An encryption key is required for encrypting the " +
                                "cookie data. Please set ActionDispatch::Cookies::EncryptedCookieJar.encryption_key = " +
                                "\"some random string of exactly " +
                                "#{ENCRYPTION_KEY_SIZE * 2} bytes\" in your initializers"
                end
                
                if encryption_key.size != ENCRYPTION_KEY_SIZE * 2
                        raise ArgumentError, "The EncryptedCookieJar encryption key must be a " +
                                "hexadecimal string of exactly #{ENCRYPTION_KEY_SIZE * 2} bytes. " +
                                "The value that you've provided, \"#{encryption_key}\", is " +
                                "#{encryption_key.size} bytes. You could use the following (randomly " +
                                "generated) string as encryption key: " +
                                ActiveSupport::SecureRandom.hex(ENCRYPTION_KEY_SIZE)
                end
        end
	def encrypt(data)
		data = Marshal.dump(data)
		@data_cipher.encrypt
		@data_cipher.key 	= @encryption_key
		@data_cipher.iv = iv = @data_cipher.random_iv
		encrypted_data = @data_cipher.update(data) << @data_cipher.final
		#encrypted_data = 'abc'
		#iv = 'a'
		"#{base64(iv)}--#{base64(encrypted_data)}"
	end
	def decrypt(data)
		b64_iv, b64_encrypted_data = data.split("--", 2)
		if b64_iv && b64_encrypted_data 
			iv 		= ActiveSupport::Base64.decode64(b64_iv)
			encrypted_data 	= ActiveSupport::Base64.decode64(b64_encrypted_data)
			@data_cipher.decrypt
			@data_cipher.key = @encryption_key
			@data_cipher.iv = iv
			data = @data_cipher.update(encrypted_data) << @data_cipher.final
			return Marshal.load(data)
		end
		return nil
		
	end
	def base64(data)
		ActiveSupport::Base64.encode64s(data)
	end

end #EncryptedCookiejar
end #Cookies
end #ActionDispatch
