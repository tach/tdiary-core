# -*- coding: utf-8; -*-
#
# tracwiki_style.rb: Trac Wiki style for tDiary 2.x format.
#
# if you want to use this style, add @style into tdiary.conf below:
#
#    @style = 'TracWiki'
#
# Copyright (C) 2005-2012 Taku YASUI <tach@debian.org>,
# modified from wiki_style.rb.
# You can distribute this under GPL.
#
require 'tdiary/tracwiki_parser'
require 'tdiary/style/wiki_style'

module TDiary
	class TracwikiSection < WikiSection
		def initialize( fragment, author = nil )
			@author = author
			if fragment[0] == ?! then
				@subtitle, @body = fragment.split( /\n/, 2 )
				@subtitle.sub!( /^=\s+(.*?)\s+=\s*$/, $1 )
			else
				@subtitle = nil
				@body = fragment.dup
			end
			@body = @body || ''
			@body.sub!( /[\n\r]+\Z/, '' )
			@body << "\n\n"
			@categories = get_categories
			@stripped_subtitle = strip_subtitle

			@subtitle_to_html = @subtitle ? to_html( "= #{@subtitle} =" ) : ''
			@body_to_html = to_html( @body )
			@html = @subtitle_to_html + "\n" + @body_to_html + "\n"
			@subtitle_to_html = strip_headings( @subtitle_to_html )
			@body_to_html = strip_headings( @body_to_html )
			@stripped_subtitle_to_html = @stripped_subtitle ? strip_headings( to_html( "!#{@stripped_subtitle}" ) ) : nil
		end

	private
		def to_html( string ) # date, idx, opt
			r = ""
			stat = nil

			parser = TracwikiParser::new( :wikiname => false ).parse( string )
			parser.each do |s|
				stat = s if s.class == Symbol
				case s

				# other headings
				when :HS1, :HS2, :HS3, :HS4, :HS5; r << "<h#{s.to_s[2,1].to_i + 2}>"
				when :HE1, :HE2, :HE3, :HE4, :HE5; r << "</h#{s.to_s[2,1].to_i + 2}>\n"

				# pargraph
				when :PS; r << '<p>'
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
	end

	class TracwikiDiary < WikiDiary
		def style
			'Tracwiki'
		end

		def append( body, author = nil )
			# body1 is a section starts without subtitle.
			# body2 are sections starts with subtitle.
			if /(.*?)^(=\s+.*\s+=)$/m =~ body
				body1 = $1
				body2 = $2
			elsif /^=\s+/ !~ body
				body1 = body
				body2 = ''
			else
				body1 = ''
				body2 = body
			end

			unless body1.empty?
				current_section = @sections.pop
				if current_section then
					body1 = "#{current_section.to_src.sub( /\n+\Z/, '' )}\n\n#{body1}"
				end
				@sections << TracwikiSection::new( body1, author )
			end
			section = nil
			body2.each_line do |l|
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

		def add_section(subtitle, body)
			@sections << TracWikiSection::new("= #{subtitle} =\n#{body}")
			@sections.size
		end
	end
end

# Local Variables:
# mode: ruby
# indent-tabs-mode: t
# tab-width: 3
# ruby-indent-level: 3
# End:
