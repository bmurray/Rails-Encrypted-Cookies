require 'encrypted_cookie_jar'

module ActionDispatch
module Session
class EncryptedCookieStore < CookieStore

private
def unpacked_cookie_data(env)
          env["action_dispatch.request.unsigned_session_cookie"] ||= begin
            stale_session_check! do
              request = ActionDispatch::Request.new(env)
              if data = request.cookie_jar.encrypted[@key]
                data.stringify_keys!
              end
              data || {}
            end
          end
end
def set_cookie(request, options)
	request.cookie_jar.encrypted[@key] = options
end
end #EncryptedCookieStore
end #Session
end #ActionDispatch
