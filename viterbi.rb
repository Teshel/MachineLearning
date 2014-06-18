#!/usr/bin/ruby

require './hmm.rb'
require './util.rb'

class Application
	attr_accessor :words, :sentence

	def initialize(hmm_filename, word_filename, input_folder)
		# view settings
		@horizontal_border = "─"
		@border = "│"
		@log_view_max = 6
		@sentence_view_max = 10
		@v_max = 10
		@cell_size = 6
		@progress_status = ""

		# load input files
		@files = find_input_files_from(input_folder)
		@total_files = @files.length
		@analyzed_files = 0

		# model manager -- handles file I/O and creating HMMs

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
		@v = []
		@blank_line = @border + (" "*(@grid_width-1)) + @border + nl

		# display before loading the HMM because it takes a while
		display()

		# now load the HMM and use the dictionary to create words
		@models = read_multi_hmm_file(hmm_filename)
		@words = make_hmm_words(word_filename, @models)
		
		@bigram_file = "bigram.txt"
		@sentence_hmm = SentenceHMM.new()
		@sentence_hmm.make_bigram()

		
	end

	def display()
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
		right_side = @progress_status.rjust(screen_half)
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

	def make_bigram()
		@sentence = HMM.new
		@word_starting_loc = {}
		@word_ending_loc = {}

		@words = @words.each_value { |word| puts("before: #{word.states.length} states, #{word.state_transitions.length} trans"); word = word + @models["sp"] }

		# need to make a huge transition matrix from all of the words
		# and use the bigram.txt to set the transitions between words
		@words["<s>"] = @models["sil"]
		@words.each_pair { |word_name, word_hmm| puts("#{word_name}: #{word_hmm.states.length} states, #{word_hmm.state_transitions.length} trans"); @sentence.states += word_hmm.states }
		@sentence.state_transitions = Array.new(@sentence.states.length) { Array.new(@sentence.states.length, 0) }

		# copy each word's transition matrix to the new huge sentence HMM
		offset = 0
		@words.each_pair do |word_name, word_hmm|
			copy_matrix(@sentence.state_transitions, word_hmm.state_transitions, offset)

			# need a hash to store the starting location of each word
			@word_ending_loc[offset+word_hmm.states.length-1] = word_name
			@word_starting_loc[offset] = word_name
			word_hmm.offset = offset

			# state_transitions is 1 too large because it includes the end state
			# (which does not actually exist)
			offset += word_hmm.states.length
		end	

		# now use the bigram file to set the transitions between words
		file = File.new(@bigram_file, "r")

		while (line = file.gets)
			# tab delimited
			parts = line.split("\t")
			if parts.length == 3
				# 	#transition_matrix[from_state][to_state] = value
				# 	@word_transitions[from_word][to_word] = value
				# 	# need to record what state words end so that we can find which words are being said later on

				if @words[parts[0]]
					# transition should be from the end of the word
					from = @words[parts[0]].offset + @words[parts[0]].states.length - 1
				end

				if @words[parts[1]]
					# transition should be to the beginning of the other word
					to = @words[parts[1]].offset
				end

				# from and to will be nil if the line contains words that aren't in @words
				if from and to
					#if @sentence.state_transitions[from][to] == 0
						trans = @words[parts[0]].end_transition
						@sentence.state_transitions[from][to] = parts[2].to_f * trans
					#else
						# if it already exists, it must be the transition to
						# the end state. need to 
					#	@sentence.state_transitions[from][to] *= parts[2].to_f
					#end
				end
			end
		end
	end

	# multi_test_input_files
	def run
		@files.each do |filename|
			@log << "Analyzing file #{filename}"
			display
			inputs = read_input_file(filename)
			#results = @words.each_pair.map {|k,w| [k, gaussian_forward(inputs, w)] }.sort_by{|a| a[1]}.reverse
			# @log << inputs.length.to_s
			# @log << inputs.first.count.to_s
			display
			result = gaussian_viterbi(inputs, @sentence)
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
		end
	end

	

	def gaussian_viterbi(obs, hmm)
		# first step of the algorithm is to initialize the starting state
		# base case
		@v = Array.new(1) { Array.new(hmm.states.length, 0) }
		paths = []
		newpath = []
		not_zeroes_initial = []
		sentence = []
		@sentences << sentence

		# initial
		# if the state is not the start of a word, it should have an
		# initial probability of 0
		hmm.states.each_with_index do |state, index|
			if obs and obs[0]
				# need a function that checks to see if state_index is
				# the start of a word
				if @word_starting_loc[index]
					@v[0][index] = state.weighted_pdf(obs[0])
					not_zeroes_initial << index
				else
					@v[0][index] = 0
				end
				paths[index] = [index] # making paths for each starting state?
			else
				@log << "obs or obs[0] is nil"
				display
			end
		end

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

					state_trans = safe_log(hmm.state_transitions[si2][state_index])

					arr << [(prev_prob + state_trans + pdf), si2]
				end

				max_prev_state = arr.max { |a, b| a.first <=> b.first }
				
				if max_value == nil or max_prev_state.first > max_value
					max_value = max_prev_state.first
					max_index = max_prev_state.last
				end

				@v[i][state_index] = max_prev_state.first
				newpath[state_index] = paths[max_prev_state.last] + [state_index]

				# show conclusions up to this observation row
				display
			end

			# find the best sentence
			best_sentence_index = max_index
			#@progress_status = "Best Sentence Index: #{best_sentence_index}"
			sentence = []
			paths[best_sentence_index].each do |word_index|
				word = @word_ending_loc[word_index]
				sentence << "#{word}(#{word_index})" if word
			end

			#@best_sentence = sentence.join(" ")

			# new paths become the old
			paths = newpath
		end
		puts ""
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