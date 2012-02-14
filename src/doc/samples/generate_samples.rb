#!/usr/bin/env ruby

require 'rubygems'
require 'amee'
require 'typhoeus'
require 'json'
require 'nokogiri'

$formats = [:json, :xml]

$conf = YAML.load_file('amee.yml').symbolize_keys
$hydra = Typhoeus::Hydra.new

#!/usr/bin/ruby
require 'rubygems'
require 'nokogiri'

XSL = <<-EOXSL
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml" encoding="ISO-8859-1"/>
<xsl:param name="indent-increment" select="' '"/>

<xsl:template name="newline">
<xsl:text disable-output-escaping="yes">
</xsl:text>
</xsl:template>

<xsl:template match="comment() | processing-instruction()">
<xsl:param name="indent" select="''"/>
<xsl:call-template name="newline"/>
<xsl:value-of select="$indent"/>
<xsl:copy />
</xsl:template>

<xsl:template match="text()">
<xsl:param name="indent" select="''"/>
<xsl:call-template name="newline"/>
<xsl:value-of select="$indent"/>
<xsl:value-of select="normalize-space(.)"/>
</xsl:template>

<xsl:template match="text()[normalize-space(.)='']"/>

<xsl:template match="*">
<xsl:param name="indent" select="''"/>
<xsl:call-template name="newline"/>
<xsl:value-of select="$indent"/>
<xsl:choose>
<xsl:when test="count(child::*) > 0">
<xsl:copy>
<xsl:copy-of select="@*"/>
<xsl:apply-templates select="*|text()">
<xsl:with-param name="indent" select="concat ($indent, $indent-increment)"/>
</xsl:apply-templates>
<xsl:call-template name="newline"/>
<xsl:value-of select="$indent"/>
</xsl:copy>
</xsl:when>
<xsl:otherwise>
<xsl:copy-of select="."/>
</xsl:otherwise>
</xsl:choose>
</xsl:template>
</xsl:stylesheet>
EOXSL



def save(name, format, request)

  # write container. This is a horrible hack as it will happen multiple times
  File.open("#{name}.xml", 'w') do |f| 
    f.puts "<section role='tabbed' xmlns:xi='http://www.w3.org/2001/XInclude'>"
    $formats.each do |x|
      f.puts "<xi:include href='#{x}/#{name}.xml'/>"
    end
    f.puts "</section>"
  end

  # Write individual output
  File.open("#{format}/#{name}.xml", 'w') do |f| 
    f.puts "<section role='tab'>"
    f.puts "<title>#{format.to_s.upcase}</title>"
  
    f.puts "<section role='httprequest'>"
    # Request header
    f.puts "<programlisting role='header'>"
    f.puts "#{request.method.to_s.upcase} /#{request.url.split('/',4).last} HTTP/1.1"
    f.puts "Accept: #{request.headers[:Accept]}"
    f.puts "Content-Type: #{request.headers[:'Content-Type']}" if request.headers[:'Content-Type']
    f.puts "Authorization: Basic dXNlcm5hbWU6cGFzc3dvcmQ="
    f.puts "</programlisting>"    
    # Request body
    unless request.body.blank?
      f.puts "<programlisting role='body'>"
      f.puts request.body
      f.puts "</programlisting>"
    end
    f.puts "</section>"
    
    response = request.response
    f.puts "<section role='httpresponse'>"
    # Response header
    f.puts "<programlisting role='header'>"
    f.puts response.headers.to_s.split("\n").first
    f.puts "Content-Type: #{response.headers_hash['Content-Type']}"
    f.puts "Location: #{response.headers_hash['Location']}" if response.headers_hash.has_key?('Location')
    f.puts "</programlisting>"
    # Response body
    unless request.response.body.blank?
      lang = format.to_s
      lang = "javascript" if lang == 'json'
      f.puts "<programlisting language='#{lang}'><![CDATA["
      case format
      when :json
        output = JSON.pretty_generate(JSON[request.response.body])
      when :xml
        xsl = Nokogiri::XSLT(XSL)
        xml = Nokogiri(request.response.body)
        output = xsl.apply_to(xml).to_s
      end
      f.puts output
      f.puts "]]></programlisting>"
    end
    f.puts "</section>"

    f.puts "</section>"
  end

end

def form_encode(data)
  data.map { |datum|
    "#{CGI::escape(datum[0].to_s)}=#{CGI::escape(datum[1].to_s)}"
  }.join('&')
end

def request(method, path, options = {})
  # Perform the request
  request_options = {
    :method       => method,
    :headers      => {:Accept => "application/#{@format}"},
    :username     => $conf[:username],
    :password     => $conf[:password]
  }
  case method
  when :post, :put
    request_options[:headers][:'Content-Type'] = 'application/x-www-form-urlencoded'
    request_options[:body] = form_encode(options) unless options.empty?
  else
    request_options[:params] = options unless options.empty?
  end
  request = Typhoeus::Request.new("https://#{$conf[:server]}#{path}", request_options)
  $hydra.queue(request)
  $hydra.run
  # Save request
  save method.to_s+path.gsub(/\/[A-Z0-9]{12}/,'/UID').gsub('/','_')+options.to_s, @format, request
  # Pass response object back
  request.response
end

$formats.each do |format|
  @format = format
  uid = nil
  begin
    # Create profile
    response = request :post, '/3/profiles', :profile => true
    profile_uid = response.headers_hash["Location"].match(/\/([A-Z0-9]{12})$/)[1]
    # Get profile list
    request :get, "/3/profiles"
    # Get drill
    response = request :get, '/3/categories/DEFRA_transport_fuel_methodology/drill', :fuel => 'petrol'
    case @format
    when :json
      data_item_uid = response.body.match(/"values":\["([A-Z0-9]{12})"\],"name":"uid"/)[1]
    when :xml
      data_item_uid = response.body.match(/<Value>([A-Z0-9]{12})<\/Value>/)[1]
    end
    # Get fuel data item
    request :get, "/3/categories/DEFRA_transport_fuel_methodology/#{data_item_uid}"
    # Do a data calculation
    request :get, "/3/categories/DEFRA_transport_fuel_methodology/#{data_item_uid};amounts", :'values.volume' => 500
    # Create a new profile item
    response = request(:post, "/3/profiles/#{profile_uid}/items", :dataItemUid => data_item_uid, :'values.volume' => 500, :name => "#{@format}_example", :startDate => '2011-01-05T00:00:00Z')
    item_uid = response.headers_hash["Location"].match(/\/([A-Z0-9]{12})$/)[1]
    # Get profile with list of used categories
    request :get, "/3/profiles/#{profile_uid};categories"
    # Get a list of items in a profile
    request :get, "/3/profiles/#{profile_uid}/items"
    # Get an existing profile item
    request :get, "/3/profiles/#{profile_uid}/items/#{item_uid};amounts"
    # Update a profile item
    request :put, "/3/profiles/#{profile_uid}/items/#{item_uid}", :'values.volume' => 1000
  ensure
    # Clear up
    request :delete, "/3/profiles/#{profile_uid}/items/#{item_uid}" if item_uid
    request :delete, "/3/profiles/#{profile_uid}" if profile_uid
  end
end