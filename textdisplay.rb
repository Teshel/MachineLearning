class TextField

end


class TextPanel

end


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

	def layout()
		
		yield 
	end

	def render()
		# build the new display
		screen = []

		# grid for the confusion matrix
		# screen << grid()

		# grid for the viterbi algorithm
		#screen << viterbi_grid()

		# most likely sentences for a given data file
		sentences_view = viewize(@sentences.drop([0, sentences_view.length-@sentence_view_max].max))
		screen += sentences_view
		# add blank spaces if the sentences view is shorter than @sentences_view_max
		num_blanks = [(@sentences_view_max - sentences_view.length), 0].max
		screen += Array.new(num_blanks, @blank_line)

		# log viewer
		# drop old entries that exceed the view size
		log_view = viewize(@log.drop([0, log_view.length-@log_view_max].max))
		# add blank spaces if the log is shorter than @log_view_max
		num_blanks = [(@log_view_max - log_view.length), 0].max
		screen += Array.new(num_blanks, @blank_line)
		screen += log_view

		# status footer
		screen << viterbi_footer()

		# clear the screen
		system("clear")

		# print the new display
		puts screen
	end
end