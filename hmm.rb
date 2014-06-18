require 'matrix.rb'

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


class SentenceHMM < HMM
	def initialize(words)
		@words = []
	end

end