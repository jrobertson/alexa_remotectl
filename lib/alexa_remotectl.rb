#!/usr/bin/env ruby

# file: alexa_remotectl.rb

# description: Experimental project to play or pause Alexa's music player using the SPA API


require 'net/http'
require 'uri'
require 'clipboard'
require 'json'

# Use the CodeWizard with the cURL command you've copied using Developer
# tools on Alexa's SPA page (within the web browser).
#
# note: to find the correct url to convert, try clicking on pause or play to
#       invoke an AJAX request

class CodeWizard

  def initialize(s='')

    return 'no curl command found' unless s =~ /curl/

    cookie, csrf, serialno, type = parse(s)

@s =<<EOF
require 'alexa_remotectl'

cookie = '#{cookie}'
csrf = '#{csrf}'
device = {serialno: '#{serialno}', type: '#{type}'}
alexa = AlexaRemoteCtl.new(cookie: cookie, csrf: csrf, device: device)
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
    csrf = s[/csrf: ([^']+)/,1]

    [cookie, csrf, serialno, type]

  end
end

class AlexaRemoteCtl

  # note: Added the Cross-site request forgery (crsf) variable
  #
  def initialize(domain: 'alexa.amazon.co.uk', device: {}, cookie: '',
      customerid: '', csrf: '')

    @domain, @device, @cookie, @customerid = domain, device, cookie, customerid
    @csrf = csrf

  end

  # Some audio streams can't be paused through the SPA API. Playing a
  # historical queue, and then pausing it, is the best next option.
  #
  def force_pause()

    r = list_hq()
    queueid = r[:media][0][:queueId]

    play_hq queueid
    sleep 1

    pause()

  end

  def info()
    device_player()[:playerInfo]
  end

  def list_ebooks()
    r = get_json '/api/ebooks/library', "mediaOwnerCustomerId=#{@customerid}" +
        "&nextToken=&size=50"
    r[:metadataList]
  end

  # list historical queue (hq)
  #
  def list_hq()
    get_json '/api/media/historical-queue', "size=50&offset=-1"
  end

  def mute?()
    info()[:volume][:muted]
  end

  alias muted? mute?

  # skip to the next music track
  def next
    pp_cmd('Next')
  end

  def pause
    pp_cmd('Pause')
  end

  def play
    pp_cmd('Play')
  end

  def play_ebook(obj)

    id = if obj.is_a? Integer then
      list_ebook()[obj][:asin]
    else
      obj
    end

    serialno = @device[:serialno]
    type = @device[:type]

    url = "https://#{@domain}/api/ebooks/queue-and-play?"

    body = {
      'asin' => id,
      'deviceType' => type,
      'deviceSerialNumber' => serialno,
      'mediaOwnerCustomerId' => @customerid
    }.to_json

    post_request url, body

  end

  # play historical queue
  # note: You can find the queueid from an entry in the list_hq() result
  #
  def play_hq(obj)

    queueid = if obj.is_a? Integer then
      r = list_hq()
      r[:media][obj][:queueId]
    else
      obj
    end

    device_phq(queueid)
  end

  def playing?()
    info()[:state] == 'PLAYING'
  end

  # Artist name
  #
  def text1()
    info()[:infoText][:subText1]
  end

  # music station
  #
  def text2()
    info()[:infoText][:subText2]
  end

  # music track title
  #
  def title()
    info()[:infoText][:title]
  end

  def vol()
    info()[:volume][:volume]
  end

  def vol=(n)

    return unless n.between? 0, 40

    body = '{"type":"VolumeLevelCommand","volumeLevel":' + n.to_s \
             + ',"contentFocusClientId":null}'
    device_cmd(body)
  end

  alias setvol vol=

  private

  # play, pause, or next
  #
  def pp_cmd(s)
    body = '{"type":"' + s + 'Command","contentFocusClientId":null}'
    device_cmd body
  end

  def device_cmd(body)

    serialno = @device[:serialno]
    type = @device[:type]

    url = "https://#{@domain}/api/np/command?deviceSerial" +
        "Number=#{serialno}&deviceType=#{type}"
    post_command url, body

  end

  # play historical queue (PHQ)
  #
  def device_phq(queueid)

    serialno = @device[:serialno]
    type = @device[:type]

    url = "https://#{@domain}/api/media/play-historical-queue"

    body = {
      'deviceType' => type,
      'deviceSerialNumber' => serialno,
      'queueId' => queueid,
      'startTime' => nil,
      'service' => nil,
      'trackSource' => nil,
      'mediaOwnerCustomerId' => @customerid
    }.to_json

    post_request url, body

  end

  def device_player()
    get_json '/api/np/player'
  end

  def get_json(uri, params='')

    serialno = @device[:serialno]
    type = @device[:type]

    url = "https://#{@domain}#{uri}?deviceSerial" +
        "Number=#{serialno}&deviceType=#{type}"
    url += '&' + params if params.length > 1

    r = get_request url
    JSON.parse(r.body, symbolize_names: true)

  end

  def make_response(uri, request)

    request["Accept"] = "application/json, text/javascript, */*; q=0.01"
    request["Accept-Language"] = "en-GB,en-US;q=0.9,en;q=0.8"
    request["Connection"] = "keep-alive"
    request["Cookie"] = @cookie

    request["Referer"] = "https://#{@domain}/spa/index.html"
    request["Sec-Fetch-Dest"] = "empty"
    request["Sec-Fetch-Mode"] = "cors"
    request["Sec-Fetch-Site"] = "same-origin"
    request["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) " +
        "AppleWebKit/537.36 (KHTML, like Gecko) " +
        "Chrome/101.0.4951.64 Safari/537.36"
    request["X-Requested-With"] = "XMLHttpRequest"
    request["csrf"] = @csrf
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

  end

  def post_command(url, body='')

    uri = URI.parse(url)
    request = Net::HTTP::Post.new(uri)
    request.body = body
    request.content_type = "application/x-www-form-urlencoded; charset=UTF-8"
    request["Origin"] = "https://" + @domain

    response = make_response(uri, request)

    # response.code
    # response.body
  end

  def get_request(url)

    uri = URI.parse(url)
    request = Net::HTTP::Get.new(uri)
    response = make_response(uri, request)

    # response.code
    # response.body

  end


  def post_request(url, body='')

    uri = URI.parse(url)
    request = Net::HTTP::Post.new(uri)
    request.body = body
    response = make_response(uri, request)

    # response.code
    # response.body

  end

end

class AlexaDevices

  # devices = [[{*serialno*, *type*}, label], ...]
  # note: label can be any identifier you choose e.g. kitchen
  #
  def initialize(devicesx=[], devices: devicesx,
                 domain: 'alexa.amazon.co.uk', cookie: '', customerid: '',
                 csrf: '', debug: false)

    @devices, @domain, @cookie = devices, domain, cookie
    @customerid, @csrf, @debug = customerid, csrf, debug

  end

  def force_pause(id) invoke(:force_pause, id)     end
  def info(id=nil)    invoke(:info, id)            end
  def list_ebooks(id) invoke(:list_ebooks, id)     end
  def list_hq(id=nil) invoke(:list_hq, id)         end
  def mute?(id=nil)   invoke2(:mute?, id)          end
  def next(id)        invoke2(:next, id)           end

  def playing()

    devices = @devices.map do |device, label|

      puts 'label: ' + label.inspect if @debug
      puts 'device: ' + device.inspect if @debug

      alexa = get_alexa device
      alexa.playing? ? [alexa, label] : nil

    end.compact

    puts 'devices: ' + devices.inspect if @debug
    return devices

  end

  def pause(id=nil)      invoke2(:pause, id)          end
  def play(id)           invoke(:play, id)            end
  def play_ebook(id)     invoke(:list_hq, id)         end
  def play_hq(id,qid)    invoke(:play_hq, id, qid)    end
  def playing?(id=nil)   invoke(:playing?, id)        end
  def text1(id=nil)      invoke2(:text1, id)          end
  def text2(id=nil)      invoke2(:text2, id)          end
  def title(id=nil)      invoke2(:title, id)          end
  def vol(id=nil)        invoke(:vol, id)             end
  def setvol(id=nil, level)  invoke(:setvol, id, level) end

  private

  def get_alexa(device)

    AlexaRemoteCtl.new(cookie: @cookie, device: device,
                       customerid: @customerid, csrf: @csrf)
  end

  def apply_cmd(a, cmd, id, args)

    if id then

      device, _ = a.find {|_, label| label.to_sym == id.to_sym}
      alexa = get_alexa device
      alexa.method(cmd).call(*args)

    else

      a.map do |device, label|

        puts cmd.to_s + ' @' + label.inspect
        alexa = get_alexa device
        alexa.method(cmd).call(*args)

      end

    end
  end

  def apply_cmd2(a, cmd, id, args)

    if id then

      alexa, _ = a.find {|_, label| label.to_sym == id.to_sym}
      alexa.method(cmd).call(*args)

    else

      a.map do |alexa, label|

        puts cmd.to_s + ' @' + label.inspect
        alexa.method(cmd).call(*args)

      end

    end
  end

  def invoke(cmd, id, *args)
    apply_cmd(@devices, cmd, id, args)
  end

  # apply command to an Alexa device which is currently playing
  #
  def invoke2(cmd, id, *args)
    apply_cmd2(playing(), cmd, id, args)
  end

end
