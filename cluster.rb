require './grid.rb'

def randompoints(n, max_x, max_y)
	Array.new(n) { p(rand(max_x), rand(max_y))}
end

# I think I misunderstand how this works
def bottom_up_clustering(points)
	points.length.times do |x|
		points.length.times do |y|
			if x != y

			end
		end
	end
end

# this one sounds terrible
# time complexity must be huge
# 
# find a cluster g_i such that e(g_i) is the largest
# ^ wouldn't that be n choose k size?
def top_down_clustering(points)

end

class ClusterManager

	def initialize(width, height)
		super(width, height, Point)
	end

	def display
		system 'clear'
		puts "_"*(@x*@col_size + 2)
		@grid.reverse.each do |row|
			puts row.map{|sq| sq.object.to_s.rjust(@col_size)}.join + " |"
		end
		puts "-"*(@x*@col_size + 2)
	end
end


def rand_grid(k, n)
	cm = ClusterManager.new(20, 15)
	clusters = []
	points = []
	k.times do
		i = 0
		cluster = nil
		loop do
			cluster = cm.random_point
			i += 1
			break if (i > 10 or clusters.map {|c| c.dist(cluster) > 6 ? 1 : 0}.inject(:+) == clusters.length)
		end
		if cluster
			clusters << cluster

			n.times do
				clusters.each do |cluster|
					points << (cluster + Point.new(rand(10)-5, rand(10)-5))
				end
			end
		end
	end
	points
end