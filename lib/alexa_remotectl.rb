#!/usr/bin/env ruby

# file: alexa_remotectl.rb

# description: Experimental project to play or pause Alexa's music player using the SPA API


require 'net/http'
require 'uri'
require 'clipboard'

# Use the CodeWizard with the cURL command you've copied using Developer
# tools on Alexa's SPA page (within the web browser).
#
# note: to find the correct url to convert, try clickin on pause or play to
#       invoke an AJAX request

class CodeWizard

  def initialize(s='')

    return 'no curl command found' unless s =~ /curl/

    cookie, serialno, type = parse(s)

@s =<<EOF
require 'alexa_remotectl'

cookie = '#{cookie}'
device = {serialno: '#{serialno}', type: '#{type}'}
alexa = AlexaRemoteCtl.new(cookie: cookie, device: device)
alexa.pause
#alexa.play
EOF

  end

  def to_s()
    Clipboard.copy @s
    puts 'copied to clipboard'

    @s
  end

  private

  def parse(s)

    serialno = s[/deviceSerialNumber=(\w+)/,1]
    type = s[/deviceType=(\w+)/,1]
    cookie = s[/Cookie: ([^']+)/,1]

    [cookie, serialno, type]

  end
end

class AlexaRemoteCtl

  def initialize(domain: 'alexa.amazon.co.uk', device: {}, cookie: '')

    @domain, @device, @cookie = domain, device, cookie

  end

  def pause
    device_cmd('Pause')
  end

  def play
    device_cmd('Play')
  end

  private

  def device_cmd(cmd)

    serialno = @device[:serialno]
    type = @device[:type]

    url = "https://#{@domain}/api/np/command?deviceSerialNumber=#{serialno}&deviceType=#{type}"
    uri = URI.parse(url)
    request = Net::HTTP::Post.new(uri)
    request.body = '{"type":"' + cmd + 'Command","contentFocusClientId":null}'
    request.content_type = "application/x-www-form-urlencoded; charset=UTF-8"

    request["Accept"] = "application/json, text/javascript, */*; q=0.01"
    request["Accept-Language"] = "en-GB,en-US;q=0.9,en;q=0.8"
    request["Connection"] = "keep-alive"
    request["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    request["Cookie"] = @cookie
    request["Origin"] = "https://" + @domain
    request["Referer"] = "https://#{@domain}/spa/index.html"
    request["Sec-Fetch-Dest"] = "empty"
    request["Sec-Fetch-Mode"] = "cors"
    request["Sec-Fetch-Site"] = "same-origin"
    request["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.64 Safari/537.36"
    request["X-Requested-With"] = "XMLHttpRequest"
    request["csrf"] = "-990908140"
    request["dnt"] = "1"
    request["sec-ch-ua"] = "\" Not A;Brand\";v=\"99\", \"Chromium\";v=\"101\""
    request["sec-ch-ua-mobile"] = "?0"
    request["sec-ch-ua-platform"] = "\"Linux\""
    request["sec-gpc"] = "1"
    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    # response.code
    # response.body

  end
end
