require 'matrix.rb'
require './util.rb'

include MatrixExtras

class State
	attr_accessor :mixtures

	def initialize
		@mixtures = []
		@current_mixture = nil
	end

	def switch_new_mixture(weight)
		if @mixtures.length < 2
			@current_mixture = {weight: weight}
			@mixtures << @current_mixture
		end
	end

	def set_mixture_mean(mean)
		@current_mixture[:mean] = Matrix.column_vector(mean.map { |n| n.to_f }) if @current_mixture and !@current_mixture[:mean]
	end

	def set_mixture_mean_total(total)
		@current_mixture[:mean_total] = total if @current_mixture and !@current_mixture[:mean_total]
	end

	def set_mixture_variance(variance)
		if @current_mixture and !@current_mixture[:variance]
			@current_mixture[:variance] = Matrix.diagonal(*variance.map { |n| n.to_f })
			@current_mixture[:inverse] = @current_mixture[:variance].inverse
			@current_mixture[:denominator] = ((2*Math::PI)**(39/2.0)) * Math.sqrt(variance.inject(:*))
		end
	end

	def set_mixture_variance_total(total)
		@current_mixture[:variance_total] = total if @current_mixture and !@current_mixture[:variance_total]
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
		safe_log(i)
	end

	def safe_log(n)
		n == 0 ? 0 : Math.log(n)
	end
end

class HMM
	attr_accessor :states, :state_transitions, :transition_size, :initial, :offset

	def initialize()
		@states = []
		@state_transitions = []
		@transition_size = 0
		@current_state = nil
		@initial = nil
		@offset = 0
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

	def end_transition
		@state_transitions[-2][-1]
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

class ModelManager
	attr_accessor :models, :words, :sentence

	def initialize(options={})
		@options = options
		defaults @options,
			{:hmm_filename => "hmm.txt",
			:word_filename => "dictionary.txt",
			:bigram_filename => "bigram.txt"}

		# HMM data structures

		# create phoneme HMMs
		@models = read_multi_hmm_file(@options[:hmm_filename])

		# now use the dictionary to create words
		@words = make_hmm_words(options[:word_filename], @models)

		# construct a sentence HMM from the words
		@sentence = SentenceHMM.new(options[:bigram_filename], @words, @models)
	end

	def word_starting_loc
		@sentence.word_starting_loc
	end

	def word_ending_loc
		@sentence.word_ending_loc
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
			parts_array = parts.split(" ")
			parts_array << "sp" if parts_array.last != "sp"
			word_hmms[word] = parts_array.map{|p| phonemes[p]}.inject(:+)
		end
		word_hmms
	end
end

class SentenceHMM < HMM
	attr_accessor :word_starting_loc, :word_ending_loc

	def initialize(bigram_file, words, models)
		super()

		@words = words
		@models = models
		@bigram_file = bigram_file
		@word_starting_loc = {}
		@word_ending_loc = {}

		# modify the words array in place and set @words to that
		# (need to add "sp" silence HMMs to the end of each word)
		#@words.each_pair do |key, word|
		#	@words[key] = word + @models["sp"]
		#end

		# need to make a huge transition matrix from all of the words
		# and use the bigram.txt to set the transitions between words
		@words["<s>"] = @models["sil"]
		@words.each_pair { |word_name, word_hmm| @states += word_hmm.states }
		@state_transitions = Array.new(@states.length) { Array.new(@states.length, 0) }

		# copy each word's transition matrix to the new huge sentence HMM
		offset = 0
		@words.each_pair do |word_name, word_hmm|
			copy_matrix(@state_transitions, word_hmm.state_transitions, offset)

			# need a hash to store the starting location of each word
			# have to subtract 2 because
			#   1 for the fact that Array#length is 1 larger than indices
			#   1 for the extra transition column (for the final state)
			#      which is dropped
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
						@state_transitions[from][to] = parts[2].to_f * trans
					#else
						# if it already exists, it must be the transition to
						# the end state. need to 
					#	@sentence.state_transitions[from][to] *= parts[2].to_f
					#end
				end
			end
		end
	end
end