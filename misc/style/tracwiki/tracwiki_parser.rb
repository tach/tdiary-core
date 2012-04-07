# tracwiki_parser.rb: Tracwiki parser for tDiary style $Revision: 1.8 $
#
# Copyright (C) 2004, Taku YASUI <tach@debian.or.jp>
# Modified from wiki_parser.rb written by TADA Tadashi <sho@spc.gr.jp>
#
# This software is distributed under the GNU General Public License
# version 2.0 or later.
#
# 2005-12-04 version 0.1
#   First Release (not completed imprementation yet)

class TracwikiParser
	class ParserQueue < Array
		def <<( s )
			$stderr.puts s if $DEBUG
			super( s )
		end
	end

	class TracwikiParseError < StandardError; end

	# opt is a Hash.
	#
	#     key  |    value    |      mean       |default 
	# ---------+-------------+-----------------+---------
	# :wikiname|true or false|parse WikiName   | true
	# :url     |true or false|make URL to link | true
	# :plugin  |true or false|parse plugin     | true
	# :absolute|true or false|only absolute URL| false
	#
	def initialize( opt = {} )
		@opt = {    # set default
			:wikiname => true,
			:url => true,
			:plugin => true,
			:absolute => false,
		}
		@opt.update( opt )
	end

	def parse( f )
		raise(TracwikiParseError, 'Parse string does not exist') unless ( f )
		@q = ParserQueue::new
		nest = 0
		f.each do |l|
			l.sub!( /[\r\n]+\Z/, '' )
			if @q.last == :FD && l != '}}}'
				@q.pop
				@q << l + "\n" << :FD
				next
			end
			case l
			when /^$/ # null string
				case @q.last
				when :FD
					@q.pop
					@q << "\n" << :FD
				else
					@q << nil
				end

			when /^----+$/ # horizontal bar
				@q << :RS << :RE

			when /^(={1,5})\s+(.*)\s+\1\s*$/ # headings
				eval( "@q << :HS#{$1.size}" )
				inline( $2 )
				eval( "@q << :HE#{$1.size}" )

			when /^(\s+)(\*|\d+\.)\s+(.*)/ # list
				r, depth, style = $3, ($1.size+1)/2, $2 == '*' ? 'U' : 'O'
				nest = 0 unless /^[UO]E$/ =~ @q.last.to_s
				tmp = []
				if nest < depth then
					(nest * 2).times do tmp << @q.pop end
					eval( "@q << :#{style}S << :LS" )
					inline( r )
					eval( "@q << :LE << :#{style}E" )
				elsif nest > depth
					(depth * 2 - 1).times do tmp << @q.pop end
					@q << :LS
					inline( r )
					@q << :LE
				else
					if @q.last.to_s == "#{style}E"
						(nest * 2 - 1).times do tmp << @q.pop end
						@q << :LS
						inline( r )
						@q << :LE
					else
						(nest * 2 - 2).times do tmp << @q.pop end
						eval( "@q << :#{style}S" )
						@q << :LS
						inline( r )
						@q << :LE 
						eval( "@q << :#{style}E" )
					end
				end
				@q << tmp.pop while tmp.size != 0
				nest = depth

			when /^\s+(.+)::\s*$/ # definition list (item)
				if @q.last == :DE then
					@q.pop
				else
					@q << :DS
				end
				@q << :DTS << inline( $1 ) << :DTE << :DE

			when /^\s+(.+)$/ # definition list (description) or block quote
				if @q.last == :DE # definition description
					@q.pop
					@q << :DDS << inline($1) << :DDE << :DE
				else # block quote
					if @q.last == :QE
						@q.pop
						@q.pop
					else
						@q << :QS << :PS
					end
					inline( $1 + "\n" )
					@q << :PE << :QE
				end

			when /^\s+$/ # block quote (null line)
				if @q.last == :QE then
					@q.pop
				else
					@q << :QS
				end
				@q << :PS << :PE << :QE

			when '{{{' # formatted text start
				@q << :FS << :FD

			when '}}}' # formatted text end
				case @q.last
				when :FD
					@q.pop
					@q << :FE
				when :PE
					@q.pop
					@q << l << :PE
				else
					@q << :PS << l << :PE
				end

			when /^\|\|(.*)/ # table
				if @q.last == :TE then
					@q.pop
					@q << :TRS
				else
					@q << :TS << :TRS
				end
				$1.split( /\|\|/ ).each do |s|
					@q << :TDS
					inline( s )
					@q << :TDE
				end
				@q << :TRE << :TE

			else # paragraph
				case @q.last
				when :PE
					@q.pop
					@q << inline( l ) << :PE
				when :FD then
					@q.pop
					@q << l + "\n" << :FD
				else
					@q << :PS << inline( l ) << :PE
				end
			end
		end
		@q.compact!
		@q
	end

	private
	def inline( l )
		if @opt[:plugin] then
			r = /(.*?)(\[\[.*?\]\]|\[|\]|'''''|'''|''|~~|__|`|\^|,,|\{\{\{|\}\}\})/
		else
			r = /(.*?)(\[|\]|'''''|'''|''|~~|__|`|\^|,,|\{\{\{|\}\}\})/
		end
		a = l.scan( r ).flatten
		tail = a.size == 0 ? l : $'
		stat = []
		a.each do |i|
			case i
			when '['
				@q << :KS
				stat.push :KE
			when ']'
				@q << stat.pop
			when '{{{'
				@q << :TTS
				stat.push :TTE
			when '}}}'
				@q << stat.pop
			when '`'
				if stat.last == :TTE then
					@q << stat.pop
				else
					@q << :TTS
					stat.push :TTE
				end
			when "'''''"
				if stat.last == :SEE then
					@q << stat.pop
				else
					@q << :SES
					stat.push :SEE
				end
			when "'''"
				if stat.last == :SE then
					@q << stat.pop
				else
					@q << :SS
					stat.push :SE
				end
			when "''"
				if stat.last == :EE then
					@q << stat.pop
				else
					@q << :ES
					stat.push :EE
				end
			when '~~'
				if stat.last == :ZE then
					@q << stat.pop
				else
					@q << :ZS
					stat.push :ZE
				end
			when '__'
				if stat.last == :ULE then
					@q << stat.pop
				else
					@q << :ULS
					stat.push :ULE
				end
			when '^'
				if stat.last == :UPE then
					@q << stat.pop
				else
					@q << :UPS
					stat.push :UPE
				end
			when ',,'
				if stat.last == :LWE then
					@q << stat.pop
				else
					@q << :LWS
					stat.push :LWE
				end
			else
				if @opt[:plugin] and /^\[\[(.*)\]\]$/ =~ i then
					@q << :GS << $1 << :GE
				elsif stat.last == :KE
					@q << i
				else
					url( i ) if i.size > 0
				end
			end
		end
		url( tail ) if tail
	end

	def url( l )
		unless @opt[:url]
			@q << l
			return
		end

		r = %r<(((https?|ftp):[\(\)%#!/0-9a-zA-Z_$@.&+-,'"*=;?:~-]+)|([0-9a-zA-Z_.-]+@[\(\)%!0-9a-zA-Z_$.&+-,'"*-]+\.[\(\)%!0-9a-zA-Z_$.&+-,'"*-]+))>
		a = l.gsub( r ) {
			if $1 == $2 then
				url = $2
				if %r<^(https?|ftp)(://)?$> =~ url then
					url
				elsif %r<^(https?|ftp)://> =~ url
					"[[#{url}]]"
				else
					if @opt[:absolute] then
						url
					else
						"[[#{url.sub( /^(https?|ftp):/, '' )}]]"
					end
				end
			else
				"[[mailto:#$4]]"
			end
		}.scan( /(.*?)(\[\[|\]\])/ ).flatten
		tail = a.size == 0 ? l : $'
		a.each do |i|
			case i
			when '[['
				@q << :XS
			when ']]'
				@q << :XE
			else
				if @q.last == :XS then
					@q << i
				else
					wikiname( i )
				end
			end
		end
		wikiname( tail ) if tail
	end

	def wikiname( l )
		unless @opt[:wikiname]
			@q << l
			return
		end

		l.gsub!( /[A-Z][a-z0-9]+([A-Z][a-z0-9]+)+/, '[[\0]]' )
		a = l.scan( /(.*?)(\[\[|\]\])/ ).flatten
		tail = a.size == 0 ? l : $'
		a.each do |i|
			case i
			when '[['
				@q << :KS
			when ']]'
				@q << :KE
			else
				@q << i
			end
		end
		@q << tail if tail
	end
end

if $0 == __FILE__
	$DEBUG = true
	TracwikiParser::new( :wikiname => true, :plugin => true ).parse( DATA )
end

__END__
