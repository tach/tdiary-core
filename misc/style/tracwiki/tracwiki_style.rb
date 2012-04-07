#
# wiki_style.rb: Trac Wiki style for tDiary 2.x format. $Revision: 1.20 $
#
# if you want to use this style, add @style into tdiary.conf below:
#
#    @style = 'TracWiki'
#
# Copyright (C) 2003, TADA Tadashi <sho@spc.gr.jp>
# You can distribute this under GPL.
#
# 2005-12-04 version 0.1
#   First Release (not completed imprementation yet)
require 'tdiary/tracwiki_parser'

module TDiary
	class TracwikiSection
		attr_reader :subtitle, :author
		attr_reader :categories, :stripped_subtitle
		attr_reader :subtitle_to_html, :stripped_subtitle_to_html, :body_to_html
	
		def initialize( fragment, author = nil )
			@author = author
			if fragment[0] == ?! then
				@subtitle, @body = fragment.split( /\n/, 2 )
				@subtitle.sub!( /^\!\s*/, '' )
			else
				@subtitle = nil
				@body = fragment.dup
			end
			@body = @body || ''
			@body.sub!( /[\n\r]+\Z/, '' )
			@body << "\n\n"
			@parser = TracwikiParser::new( :wikiname => false ).parse( to_src )

			@categories = get_categories
			@stripped_subtitle = strip_subtitle

			@subtitle_to_html = @subtitle ? to_html("!#{@subtitle}") : nil
			@stripped_subtitle_to_html = @stripped_subtitle ? to_html("!#{@stripped_subtitle}") : nil
			@body_to_html = to_html(@body)
		end

		def body
			@body.dup
		end

		def to_src
			r = ''
			r << "! #{@subtitle}\n" if @subtitle
			r << @body
		end

		def html4( date, idx, opt )
			r = %Q[<div class="section">\n<%=section_enter_proc( Time::at( #{date.to_i} ))%>\n]
			r << do_html4( @parser, date, idx, opt )
			r << "<%=section_leave_proc( Time::at( #{date.to_i} ))%>\n</div>\n"
		end

		def do_html4( parser, date, idx, opt )
			r = ""
			stat = nil
			subtitle = false
			parser.each do |s|
				stat = s if s.class == Symbol
				case s

				# subtitle heading
				when :HS1
					r << "<h3>"
					if date
						r << "<a "
						if opt['anchor'] then
							r << %Q[name="p#{'%02d' % idx}" ]
						end
						r << %Q[href="#{opt['index']}<%=anchor "#{date.strftime( '%Y%m%d' )}#p#{'%02d' % idx}" %>">#{opt['section_anchor']}</a> ]
					end
					if opt['multi_user'] and @author then
						r << %Q|[#{@author}]|
					end
					subtitle = true
				when :HE1; r << "</h3>\n"

				# other headings
				when :HS2, :HS3, :HS4, :HS5; r << "<h#{s.to_s[2,1].to_i + 2}>"
				when :HE2, :HE3, :HE4, :HE5; r << "</h#{s.to_s[2,1].to_i + 2}>\n"

				# pargraph
				when :PS
					r << '<p>'
					if (!subtitle and date) then
						r << '<a '
						if opt['anchor'] then
							r << %Q[name="p#{'%02d' % idx}" ]
						end
						r << %Q[href="#{opt['index']}<%=anchor "#{date.strftime( '%Y%m%d' )}#p#{'%02d' % idx}" %>">#{opt['section_anchor']}</a>]
					end
				when :PE; r << "</p>\n"

				# horizontal line
				when :RS; r << "<hr>\n"
				when :RE

				# blockquote
				when :QS; r << "<blockquote>\n"
				when :QE; r << "</blockquote>\n"

				# list
				when :US; r << "<ul>\n"
				when :UE; r << "</ul>\n"

				# ordered list
				when :OS; r << "<ol>\n"
				when :OE; r << "</ol>\n"

				# list item
				when :LS; r << "<li>"
				when :LE; r << "</li>\n"

				# definition list
				when :DS; r << "<dl>\n"
				when :DE; r << "</dl>\n"
				when :DTS; r << "<dt>"
				when :DTE; r << "</dt>"
				when :DDS; r << "<dd>"
				when :DDE; r << "</dd>\n"

				# formatted text
				when :FS; r << '<pre>'
				when :FD; r << "</pre>\n"
				when :FE; r << "</pre>\n"

				# table
				when :TS; r << "<table border=\"1\">\n"
				when :TE; r << "</table>\n"
				when :TRS; r << "<tr>\n"
				when :TRE; r << "</tr>\n"
				when :TDS; r << "<td>"
				when :TDE; r << "</td>"

				# emphasis
				when :ES; r << "<em>"
				when :EE; r << "</em>"

				# strong
				when :SS; r << "<strong>"
				when :SE; r << "</strong>"

				# enphasis/strong
				when :SES; r << "<strong><em>"
				when :SEE; r << "</em></strong>"

				# monospace
				when :TTS; r << "<tt>"
				when :TTE; r << "</tt>"

				# delete
				when :ZS; r << "<del>"
				when :ZE; r << "</del>"

				# underline
				when :ULS; r << '<span class="underline">'
				when :ULE; r << '</span>'

				# upper
				when :UPS; r << '<sup>'
				when :UPE; r << '</sup>'

				# lower
				when :LWS; r << '<sub>'
				when :LWE; r << '</sub>'

				# Keyword
				when :KS; r << '<'
				when :KE; r << '>'

				# Plugin
				when :GS; r << '<%='
				when :GE; r << '%>'

				# URL
				when :XS; #r << '<a href="'
				when :XE; #r << '</a>'

				else
					s = CGI::escapeHTML( s ) unless stat == :GS
					case stat
					when :KS
						r << keyword(s)
					when :XS
						case s
						when /^mailto:/
							r << %Q[<a href="#{s}">#{s.sub( /^mailto:/, '' )}</a>]
						when /\.(jpg|jpeg|png|gif)$/
							r << %Q[<img src="#{s}" alt="#{File::basename( s )}">]
						else
							r << %Q[<a href="#{s}">#{s}</a>]
						end
					when :HS1
						r << s.sub(/^(\[([^\[]+?)\])+/) do
							$&.gsub(/\[(.*?)\]/) do
								$1.split(/,/).collect do |c|
									%Q|<%= category_anchor("#{c}") %>|
								end.join
							end
						end
					else
						r << s if s.class == String
					end
				end
			end
			r
		end
	
		def chtml( date, idx, opt )
			r = ''
			stat = nil
			subtitle = false
			@parser.each do |s|
				stat = s if s.class == Symbol
				case s

				# subtitle heading
				when :HS1
					r << %Q[<H3><A NAME="p#{'%02d' % idx}">*</A> ]
					if opt['multi_user'] and @author then
						r << %Q|[#{@author}]|
					end
					subtitle = true
				when :HE1; r << "</H3>\n"

				# other headings
				when :HS2, :HS3, :HS4, :HS5; r << "<H#{s.to_s[2,1].to_i + 2}>"
				when :HE2, :HE3, :HE4, :HE5; r << "</H#{s.to_s[2,1].to_i + 2}>\n"

				# paragraph
				when :PS
					r << '<P>'
					unless subtitle then
						r << '<A '
						if opt['anchor'] then
							r << %Q[NAME="p#{'%02d' % idx}"]
						end
						r << %Q[>*</A>]
					end
				when :PE; r << "</P>\n"

				# horizontal line
				when :RS; r << "<HR>\n"
				when :RE

				# blockquote
				when :QS; r << "<BLOCKQUOTE>\n"
				when :QE; r << "</BLOCKQUOTE>\n"

				# list
				when :US; r << "<UL>\n"
				when :UE; r << "</UL>\n"

				# ordered list
				when :OS; r << "<OL>\n"
				when :OE; r << "</OL>\n"

				# list item
				when :LS; r << "<LI>"
				when :LE; r << "</LI>\n"

				# definition list
				when :DS; r << "<DL>\n"
				when :DE; r << "</DL>\n"
				when :DTS; r << "<DT>"
				when :DTE; r << "</DT>"
				when :DDS; r << "<DD>"
				when :DDE; r << "</DD>\n"

				# formatted text
				when :FS; r << '<PRE>'
				when :FE; r << "</PRE>\n"

				# table
				when :TS; r << "<TABLE BORDER=\"1\">\n"
				when :TE; r << "</TABLE>\n"
				when :TRS; r << "<TR>\n"
				when :TRE; r << "</TR>\n"
				when :TDS; r << "<TD>"
				when :TDE; r << "</TD>"

				# emphasis
				when :ES; r << "<EM>"
				when :EE; r << "</EM>"

				# strong
				when :SS; r << "<STRONG>"
				when :SE; r << "</STRONG>"

				# delete
				when :ZS; r << "<DEL>"
				when :ZE; r << "</DEL>"

				# Keyword
				when :KS; r << '<'
				when :KE; r << '>'

				# Plugin
				when :GS; r << '<%='
				when :GE; r << '%>'

				# URL
				when :XS; r << '<A HREF="'
				when :XE; r << '</A>'

				else
					s = CGI::escapeHTML( s ) unless stat == :GS
					case stat
					when :KS
						r << keyword(s, true)
					when :XS
						r << s << '">' << s.sub( /^mailto:/, '' )
					else
						r << s if s.class == String
					end
				end
			end
			r
		end

		def to_s
			to_src
		end

	private
		def keyword( s, mobile = false )
			r = ''
			if /\s+/ =~ s
				u, k = s.split( /\s+/, 2 )
				if /^(\d{4}|\d{6}|\d{8})[^\d]*?#?([pct]\d\d)?$/ =~ u then
					r << %Q[%=my '#{$1}#{$2}', '#{k}' %]
				elsif /:/ =~ u
					scheme, path = u.split( /:/, 2 )
					if /\A(?:http|https|ftp|mailto)\z/ =~ scheme
						if mobile
							r << %Q[A HREF="#{u}">#{k}</A]
						else
							r << %Q[a href="#{u}" class="ext-link">#{k}</a]
						end
					else
						r << %Q[%=kw '#{u}', '#{k}'%]
					end
				else
					r << %Q[a href="#{u}" class="ext-link">#{k}</a]
				end
			else
				r << %Q[%=kw '#{s}' %]
			end
			r
		end

		def to_html(string)
			parser = TracwikiParser::new( :wikiname => false ).parse( string )
			parser.delete_at(0) if parser[0] == :HS1
			parser.delete_at(-1) if parser[-1] == :HE1
			r = do_html4(parser, nil, nil, {})
			if r == ""
				nil
			else
				r
			end
		end

		def get_categories
			return [] unless @subtitle
			cat = /^(\[([^\[]+?)\])+/.match(@subtitle).to_a[0]
			return [] unless cat
			cat.scan(/\[(.*?)\]/).collect do |c|
				c[0].split(/,/)
			end.flatten
		end

		def strip_subtitle
			return nil unless @subtitle
			r = @subtitle.sub(/^(\[[^\[]+?\])+\s*/,'')
			if r == ""
				nil
			else
				r
			end
		end
	end

	class TracwikiDiary
		include DiaryBase
		include CategorizableDiary
	
		def initialize( date, title, body, modified = Time::now )
			init_diary
			replace( date, title, body )
			@last_modified = modified
		end
	
		def style
			'Tracwiki'
		end
	
		def replace( date, title, body )
			set_date( date )
			set_title( title )
			@sections = []
			append( body )
		end
	
		def append( body, author = nil )
			section = nil
			body.each do |l|
				case l
				when /^=\s+.*\s+=\s*$/
					@sections << TracwikiSection::new( section, author ) if section
					section = l
				else
					section = '' unless section
					section << l
				end
			end
			@sections << TracwikiSection::new( section, author ) if section
			@last_modified = Time::now
			self
		end
	
		def each_section
			@sections.each do |section|
				yield section
			end
		end
	
		def to_src
			@sections.join
		end
	
		def to_html( opt, mode = :HTML )
			r = ''
			idx = 1
			each_section do |section|
				case mode
				when :CHTML
					r << section.chtml( date, idx, opt )
				else
					r << section.html4( date, idx, opt )
				end
				idx += 1
			end
			return r
		end
	
		def to_s
			"date=#{date.strftime('%Y%m%d')}, title=#{title}, body=[#{@sections.join('][')}]"
		end
	end
end

