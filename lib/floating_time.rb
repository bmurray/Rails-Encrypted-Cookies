class FloatingTime
	def initialize(diff=nil)
		@diff = diff || 0.seconds
	end
	def method_missing(method, *arguments, &block)
		t = Time.now + @diff
		t.send(method, *arguments, &block)
	end
end
