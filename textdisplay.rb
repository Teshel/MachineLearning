class TextDisplay
	def defaults(h, d)
		d.each_key { |k| h[k] ||= d[k] }
	end

	def initialize(options)
		@drawing = {
			:border_right_junction => "┤",
			:border_left_junction => "┤",
			:border_top_junction => "┬",
			:border_bottom_junction => "┴",
			:border_bottom_right_corner => "┘",
			:border_bottom_left_corner => "└",
			:border_top_right_corner => "┐",
			:border_top_left_corner => "┌"
		}
	end

	def panel()

	end
end