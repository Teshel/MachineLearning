#!/usr/bin/ruby
require 'matrix.rb'

class State
	attr_accessor :mixtures

	def initialize
		@mixtures = []
		@current_mixture = nil
	end

	def switch_new_mixture(weight)
		@current_mixture = {weight: weight}
		@mixtures << @current_mixture
	end

	def set_mixture_mean(mean)
		@current_mixture[:mean] = Matrix.column_vector(mean.map { |n| n.to_f }) if @current_mixture
	end

	def set_mixture_mean_total(total)
		@current_mixture[:mean_total] = total if @current_mixture
	end

	def set_mixture_variance(variance)
		@current_mixture[:variance] = Matrix.diagonal(*variance.map { |n| n.to_f }) if @current_mixture
		@current_mixture[:inverse] = @current_mixture[:variance].inverse
		@current_mixture[:denominator] = ((2*Math::PI)**(39/2.0)) * Math.sqrt(variance.inject(:*)) if @current_mixture
	end

	def set_mixture_variance_total(total)
		@current_mixture[:variance_total] = total if @current_mixture
	end

	def weighted_pdf(x)
		i = 0
		mixtures.each do |mixture|
			mean = mixture[:mean]
			inverse_variance = mixture[:inverse]
			denominator = mixture[:denominator]
			x_mu_diff = (x - mean)
			e = Math.exp(-0.5 * ((x_mu_diff.transpose * inverse_variance) * x_mu_diff).first)

			i += mixture[:weight] * (e/denominator)
		end
		Math.log(i)
	end
end

class HMM
	attr_accessor :states, :state_transitions, :transition_size, :initial

	def initialize()
		@states = []
		@state_transitions = []
		@transition_size = 0
		@current_state = nil
		@initial = nil
	end

	def set(entry, value)
		@last = entry
		case entry
		when "MIXTURE"
			# create a new mixture and pass the second part of value
			# to set the weight
			@current_state.switch_new_mixture(value.split(" ").last.to_f) if @current_state
		when "MEAN"
			@current_state.set_mixture_mean_total(value.to_f) if @current_state
		when "VARIANCE"
			@current_state.set_mixture_variance_total(value.to_f) if @current_state
		when "STATE"
			#switch_state(value.to_i)
			new_state
		when "TRANSP"
			@transition_size = value.to_f-1
		end
	end

	def switch_state(value)
		if @states[value-1]
			@current_state = @states[value-1]
		else
			@current_state = State.new
			@states[value-1] = @current_state
		end
	end

	def new_state
		@current_state = State.new
		@states << @current_state
	end

	def update_last(value)
		if @last == "VARIANCE"
			@current_state.set_mixture_variance(value) if @current_state
			@last == ""
		elsif @last == "MEAN"
			@current_state.set_mixture_mean(value) if @current_state
			@last == ""
		elsif @last == "TRANSP"
			if @initial == nil
				# initial probability
				@initial = value
			else
				@state_transitions << value.drop(1)
			end
		end
	end

	def print_trans
		cell_size = 9
		puts (" "*cell_size) + (1..@state_transitions.size).map {|i| "s#{i}".ljust(cell_size)}.join
		@state_transitions.each_with_index do |trans, i|
			puts "s#{i+1}".ljust(cell_size) + trans.map {|n| ((n*100).round(1).to_s + "%").ljust(cell_size)}.join
		end
		nil
	end

	def +(other_hmm)
		r = HMM.new
		r.states = @states + other_hmm.states
		
		# need to combine state transitions
		# each 
		size = @state_transitions.size + other_hmm.state_transitions.size - 1
		offset = @state_transitions.size - 1
		r.initial = @initial + Array.new(other_hmm.states.size, 0)
		r.state_transitions = Array.new(size) { Array.new(size, 0) }

		@state_transitions[0...-1].each_with_index do |row, ri|
			row[0..row.length-1].each_with_index do |column, ci|
				r.state_transitions[ri][ci] = column
			end
		end

		other_hmm.state_transitions.each_with_index do |row, ri|
			row.each_with_index do |column, ci|
				r.state_transitions[ri+offset][ci+offset] = column
			end
		end

		r
	end
end

class Application
	def initialize(hmm_filename, word_filename, input_folder)
		# view settings
		@horizontal_border = "-"
		@border = "|"
		@log_view_max = 10
		@cell_size = 6

		# load input files
		@files = find_input_files_from(input_folder)
		@total_files = @files.length
		@analyzed_files = 0

		# initial log
		@log = ["Loading HMM parameters... "]
		#puts "Analyzing files."

		# configure the confusion matrix display grid
		@classes = 10
		@grid_width = (@cell_size + 1)*(@classes + 1) - 1
		@confusion = Array.new(@classes) { Array.new(@classes, 0) }
		@class_map = {
			"oh" => 0,
			"zero" => 0,
			"one" => 1,
			"two" => 2,
			"three" => 3,
			"four" => 4,
			"five" => 5,
			"six" => 6,
			"seven" => 7,
			"eight" => 8,
			"nine" => 9
		}

		@blank_line = @border + (" "*(@grid_width-1)) + @border + nl

		# display before loading the HMM because it takes a while
		display()

		# now load the HMM and use the dictionary to create words
		@models = read_multi_hmm_file(hmm_filename)
		@words = make_hmm_words(word_filename, @models)

		run
	end

	def display
		# build the new display
		screen = []

		# grid for the confusion matrix
		screen << grid()

		# log viewer
		log_view = viewize(@log)
		# blank spaces if the log is shorter than @log_view_max
		num_blanks = [(@log_view_max - log_view.length), 0].max
		screen += Array.new(num_blanks, @blank_line)
		# drop old entries that exceed the view size
		screen += log_view.drop([0, log_view.length-@log_view_max].max)

		# status footer
		screen << footer()

		# clear the screen
		system("clear")

		# print the new display
		puts screen
	end

	def hr
		@horizontal_border * (@grid_width + 1)
	end

	def nl
		"\n"
	end

	def grid
		# grid header
		header = hr + nl + @border + ("Observations ".rjust(@grid_width-1)) + @border + nl + hr + nl + (" "*(@cell_size)) + @border + (0..@classes-1).to_a.map {|i| i.to_s.rjust(@cell_size)}.join(@border) + @border

		# grid content
		content = []
		@confusion.each_with_index do |row, ri|
			content << hr
			content << (ri.to_s.ljust(@cell_size) + @border + row.map {|i| i.to_s.rjust(@cell_size)}.join(@border) + @border)
		end
		content << hr

		header + nl + content.join(nl)
	end

	def footer
		hr + nl + (@border + " #{@analyzed_files}/#{@total_files} files analyzed").ljust(@grid_width-@border.length) + " " + @border + nl + hr + nl
	end

	# returns an array of strings to be printed
	def viewize(string_array)
		border_size = @border.length*2 + 2
		string_array.map do |str|
			wrap(str, border_size).map {|s| [[@border, s].join(" ").ljust(@grid_width-@border.length), @border].join(" ")}
		end
	end

	def wrap(string, border_size)
		string.scan(/\S.{0,#{@grid_width-border_size}}\S(?=\s|$)|\S+/)
	end

	def words_fast_pass(word_filename)
		file = File.new(word_filename)
		i = 0
		while (line = file.gets)
			i += 1
		end
		i
	end

	def find_input_files_from(folder)
		txtfiles = File.join(folder, "**", "*.txt")
		Dir.glob(txtfiles)
	end

	# multi_test_input_files
	def run
		@files.each do |filename|
			@log << "Analyzing file #{filename}"
			display
			inputs = read_input_file(filename)
			results = @words.each_pair.map {|k,w| [k, gaussian_forward(inputs, w)]}.sort_by{|a| a[1]}.reverse
			@log << "\n#{filename}: #{results[0][0]}:#{results[0][1].round(2)}, #{results[1][0]}:#{results[1][1].round(2)}"
			observed = results.first.first
			observed_num = @class_map[observed]
			if filename =~ /^.+_([0-9])\.txt$/
				actual = $1.to_i
				@confusion[actual][observed_num] = @confusion[actual][observed_num] + 1
			else
				@log << "Filename #{filename} doesn't contain a proper classification."
			end
			@analyzed_files += 1
			display
		end
	end

	# file I/O
	def read_hmm_file(filename)
		file = File.new(filename, "r")
		model = HMM.new

		while (line = file.gets)
			if line =~ /^~(.+) "(.+)"/
				model.switch_emission($2)
			elsif line =~ /\<([A-Z]+)\>(.+)$/
				if current_model
					current_model.set($1, $2)
				end
			else
				current_model.update_last(line.split(" ").map { |n| n.to_f }) if current_model
			end
		end
		file.close

		models
	end

	# multiple HMMs
	# constructs an array of HMMs for each phoneme
	def read_multi_hmm_file(filename)
		file = File.new(filename, "r")
		models = {}
		current_model = nil

		while (line = file.gets)
			if line =~ /^~(.+) "(.+)"/
				current_model = HMM.new
				models[$2] = current_model
			elsif line =~ /\<([A-Z]+)\>(.+)$/
				if current_model
					current_model.set($1, $2)
				end
			else
				current_model.update_last(line.split(" ").map { |n| n.to_f }) if current_model
			end
		end
		file.close

		models
	end

	def make_hmm_words(filename, phonemes)
		file = File.new(filename, "r")
		word_hmms = {}

		while (line = file.gets)
			word, parts = line.split("\t")
			#puts "word: #{word}"
			#puts "parts: #{parts}"
			word_hmms[word] = parts.split(" ").map{|p| phonemes[p]}.inject(:+)
		end
		word_hmms
	end

	def read_input_file(filename)
		file = File.new(filename, "r")
		inputs = []

		header = file.gets
		while (line = file.gets)
			inputs << Matrix.column_vector(line.split(" ").map {|n| n.to_f})
		end

		inputs
	end

	# linear algebra helper functions
	def add_logs(l1, l2)
		l2 + Math.log(1 + Math::E**(l1-l2))
	end

	def sum_logs(a)
		r = 0
		a.each_slice(2) do |v|
			if v.length > 1
				r = add_logs(v[0], v[1])
			else 
				r = add_logs(r, v[0])
			end
		end
		r
	end

	def gaussian_forward(observations, hmm)
		# the multivariate Gaussian replaces e in the forward algorithm

		forward = []
		forward_prev = []
		observations.each_with_index do |value, index|
			forward_curr = []
			hmm.states.each_with_index do |state, state_index|
				if index == 0
					prev_f_sum = hmm.initial[state_index]
				else
					prev_f_sum = 0
					hmm.states.length.times do |k|
						# these are log likelihoods so the computations have to be changed
						l1 = prev_f_sum
						l2 = (forward_prev[k] + hmm.state_transitions[k][state_index])

						prev_f_sum = add_logs(l1, l2)
					end
				end
				# there are multiple HMMs for each sound and only the value is passed
				forward_curr[state_index] =  state.weighted_pdf(value) + prev_f_sum
			end

			forward << forward_curr
			forward_prev = forward_curr
		end
		print "."

		# I think we just need to sum all of the probabilities of the last row (forward.last)
		r = 0
		# but remember these are log values so they need to be added specially
		sum_logs(forward_prev)
	end
end

def test_input_file(hmm_filename, word_filename, input_filename)
	models = read_multi_hmm_file(hmm_filename)
	words = make_hmm_words(word_filename, models)
	inputs = read_input_file(input_filename)
	result = words.each_pair.map {|k,w| [k, gaussian_forward(inputs, w)]}.sort_by{|a| a[1]}.last

	puts "#{input_filename}: #{result}"
end

def test_hmm_addition
	models = read_multi_hmm_file("hmm.txt")
	models["k"] + models["ah"]
end

def test_state
	models = read_hmm_file("hmm.txt")
	models.first

	observations = Matrix.column_vector(obs_data.map {|n| n.to_f})

	mg = MultivariateGaussian.new(1.0, mean, variance)
	mg.pdf(observations)
end

def test_app
	Application.new("hmm.txt", "dictionary.txt", "tst/")
end

test_app