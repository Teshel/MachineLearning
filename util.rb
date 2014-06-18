def ld
	if $quickload
		$quickload.each do |file|
			load file
		end
	end
end

def quickload(file)
	$quickload = [] unless $quickload
	$quickload << file unless $quickload.include? file
end

def ql(file)
	quickload(file)
end

def defaults(h, d)
	d.each_key {|k| h[k] ||= d[k]}
end

Infin = (1.0/0.0) unless defined? Infin

module MatrixExtras
	# general math helper functions

	# add two log values together
	def add_logs(l1, l2)
		l2 + Math.log(1 + Math::E**(l1-l2))
	end

	# sum an array of log values
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

	# take the log but return 0 if n is 0
	def safe_log(n)
		n == 0 ? 0 : Math.log(n)
	end

	# matrix helper functions
	def copy_matrix(to_matrix, from_matrix, offset)
		puts "to_matrix: #{to_matrix.length}, from_matrix: #{from_matrix.length}"
		from_matrix[0...-1].each_with_index do |row, y|
			row.each_with_index do |trans, x|
				to_matrix[y+offset][x+offset] = trans
			end
		end
	end

	def matrix(height, width)
		Array.new(height) { Array.new(width, 0) }
	end

	def random_matrix(height, width, rmax = 100)
		Array.new(height) { Array.new(width) { rand(rmax) } }
	end

	def print_matrix(m, cell_size=4)
		m.each do |row|
			puts row.map{|cell| cell.to_s.rjust(cell_size)}.join " "
		end
	end
end