#!/usr/bin/ruby

require './hmm.rb'
require './util.rb'

class Application
	attr_accessor :words, :manager, :sentences, :v

	def initialize(options={})
		defaults options, {:input_folder => "tst"}

		# view settings
		@horizontal_border = "─"
		@border = "│"
		@log_view_max = 6
		@sentences_view_max = 10
		@v_max = 10
		@cell_size = 6
		@progress_status = ""

		# load input files
		@files = find_input_files_from(options[:input_folder])
		@total_files = @files.length
		@analyzed_files = 0

		# initial log
		@log = ["Loading HMM parameters... "]

		# initial sentences view
		@sentences = []

		# configure the confusion matrix display grid
		@classes = 10
		@grid_width = (@cell_size + 1)*(@classes + 1) - 1
		#@confusion = Array.new(@classes) { Array.new(@classes, 0) }
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

		# viterbi matrix?
		@v = []

		# display before loading the HMM because it takes a while
		display()

		# model manager -- handles file I/O and creating HMMs
		@manager = ModelManager.new(options)
		
		run
	end

	def display()
		# build the new display
		screen = []

		# grid for the confusion matrix
		# screen << grid()

		# grid for the viterbi algorithm
		#screen << viterbi_grid()

		# most likely sentences for a given data file
		sentences_view = viewize(@sentences.drop([0, @sentences.length-@sentences_view_max].max).map{ |s_a| s_a.join(" ") })
		screen += sentences_view
		# add blank spaces if the sentences view is shorter than @sentences_view_max
		num_blanks = [(@sentences_view_max - sentences_view.length), 0].max
		screen += Array.new(num_blanks, @blank_line)

		screen << nl + hr + nl

		# log viewer
		# drop old entries that exceed the view size
		log_view = viewize(@log.drop([0, @log.length-@log_view_max].max))
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

	def viterbi_grid
		content = []

		# header
		content << borderize(" "*@grid_width)
		if @v.length > 0
			# grid content
			# limited screen space so only the last rows are shown
			# the rest are dropped
			drop_amount = [0, @v.length-@v_max].max
			@v.drop(drop_amount).each_with_index do |row, row_index|
				# displaying all of the probabilities will take up too much screen space
				# let's try just showing the order
				# row_sorted_by_prob_asc = row.each_with_index.map {|v, i| [v.to_f, i]}.sort_by {|a| a.first }
				# #while prob_index_pair.length > 0
				# #	row_sorted_by_prob_asc

				# # now collect everything and use the index as the order
				# arr = Array.new(row.length, 0)
				# row_sorted_by_prob_asc.each_with_index do |v, i|
				# 	if v.first != 0
				# 		arr[v.last] = i
				# 	end
				# end

				content << (row_index+drop_amount).to_s.rjust(3) + "| " + row[0..8].map {|v| v.round(0).to_s.rjust(6) }.join(" ")
			end
		end

		# best word
		if @best_sentence
			content << borderize_rstretch(@best_sentence)
		end

		content.join(nl)
	end

	def borderize(content)
		hr + nl + @border + content + @border + nl + hr
	end

	def borderize_rstretch(content)
		borderize(content.rjust(@grid_width-1))
	end

	def footer
		hr + nl + (@border + " #{@analyzed_files}/#{@total_files} files analyzed").ljust(@grid_width-@border.length) + " " + @border + nl + hr + nl
	end

	def viterbi_footer
		screen_half = (@grid_width-@border.length)/2
		left_side = (" #{@analyzed_files}/#{@total_files} files analyzed").ljust(screen_half)
		right_side = "#{@progress_status} ".rjust(screen_half)
		borderize(left_side + right_side)
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

	# multi_test_input_files
	def run
		#@files.each do |filename|
		filename = "tst_viterbi/f/ak/44z5938.txt"
			@log << "Analyzing file #{filename}"
			display
			inputs = read_input_file(filename)
			

			#results = @words.each_pair.map {|k,w| [k, gaussian_forward(inputs, w)] }.sort_by{|a| a[1]}.reverse
			# @log << inputs.length.to_s
			# @log << inputs.first.count.to_s
			
			result = gaussian_viterbi(inputs, @manager.sentence)
			#@log << "\n#{filename}: #{results[0][0]}:#{results[0][1].round(2)}, #{results[1][0]}:#{results[1][1].round(2)}"
			@log << "\n#{filename}: #{result}"
			# observed = results.first.first
			# observed_num = @class_map[observed]
			# if filename =~ /^.+_([0-9])\.txt$/
			# 	actual = $1.to_i
			# 	@confusion[actual][observed_num] = @confusion[actual][observed_num] + 1
			# else
			# 	@log << "Filename #{filename} doesn't contain a proper classification."
			# end
			@analyzed_files += 1
			display
		#end
	end

	def gaussian_viterbi(obs, hmm)
		# first step of the algorithm is to initialize the starting state
		# base case
		@v = Array.new(1) { Array.new(hmm.states.length, 0) }
		paths = []
		newpath = []
		view_sentence_index = @sentences.length
		best_sentence_index = 0

		# initial
		# if the state is not the start of a word, it should have an
		# initial probability of 0
		hmm.states.each_with_index do |state, index|
			if obs and obs[0]
				# need a function that checks to see if state_index is
				# the start of a word
				if @manager.word_starting_loc[index]
					@v[0][index] = state.weighted_pdf(obs[0])
					#not_zeroes_initial << index
				else
					@v[0][index] = 0
				end
				paths[index] = [index] # making paths for each starting state?
			else
				@log << "obs or obs[0] is nil"
				display
			end
		end

		max_value = nil

		obs[1..-1].each_with_index do |data, index|
			#print "."
			i = index + 1
			@v << Array.new(hmm.states.length, 0)

			# these represent the maximum values and the state index for that
			# for this observation row
			max_index = 0
			max_value = nil
			newpath = Array.new(hmm.states.length) { Array.new }

			# outer loop is iterating over the states of the next generation
			hmm.states.each_with_index do |state, state_index|
				# inner loop is iterating over the previous states
				# and multiplying that by the pdf of current generation's
				# data into the outer loop's current state
				# also the state_transition is incorporated
				# and then the max is found
				#v[i][state_index], prev_state = hmm.states.each_with_index.map { |s2, si2| [v[index][si2] * hmm.state_transitions[si2][state_index] * state.weighted_pdf(data), si2] }.max

				# something wrong with above code
				# let's test it
				arr = []
				pdf = state.weighted_pdf(data)
				#prev_max = 0
				hmm.states.each_with_index do |s2, si2|
					prev_prob = @v[index][si2]
					#@log << "previous probability: #{prev_prob}"
					# need to check for 0 here
					# or use infinity
					state_trans = safe_log(hmm.state_transitions[si2][state_index])
					if prev_prob != 0 and pdf != 0 and state_trans != 0
						arr << [(prev_prob + state_trans + pdf), si2]
					else
						arr << [0, si2]
					end
				end

				# definitely wrong because it will always pick states that are 0

				# max_prev_state = arr.max do |a, b|
				# 	if a == 0
				# 		-1
				# 	else
				# 		a.first <=> b.first
				# 	end
				# end

				max_prev_state = arr.map { |a| a.first == 0 ? [-Infin, a.last] : a }.max 
				#local_max = 0
				#arr.each do |a|
				
				#end

				if max_value == nil or max_prev_state.first > max_value
					max_value = max_prev_state.first
					max_index = max_prev_state.last
				end

				@v[i][state_index] = max_prev_state.first
				newpath[state_index] = paths[max_prev_state.last] + [state_index]

				# show conclusions up to this observation row
				#display
			end

			# find the best sentence
			best_sentence_index = max_index
			#@progress_status = "Best Sentence Index: #{best_sentence_index}"
			 @sentences[view_sentence_index] = []
			 paths[best_sentence_index].each do |word_index|
			 	word = @manager.word_ending_loc[word_index]
			 	@sentences[view_sentence_index] << "#{word}" if word
			 end

			#sentence = sentence_array.join(" ")

			#@best_sentence = sentence.join(" ")
			# new paths become the old
			paths = newpath
		end

		sentence = []
		paths[best_sentence_index].each do |word_index|
			word = @manager.word_ending_loc[word_index]
			if word
				sentence << "#{word_index}(#{word})" 
			else
				sentence << "#{word_index}"
			end
		end
		@sentences << sentence
		sentence.join(" ")
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

	def find_input_files_from(folder)
		txtfiles = File.join(folder, "**", "*.txt")
		Dir.glob(txtfiles)
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
	Application.new("hmm.txt", "dictionary.txt", "tst_viterbi/")
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

def test_mean(app)
	app.sentence.states.each_with_index do |state, si|
		state.mixtures.each_with_index do |mixture, mi|
			print "#{si}:#{mi} " if mixture[:mean] == nil
		end
	end
	puts ""
	nil
end

#test_app