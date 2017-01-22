#!/usr/local/bin/ruby
# encoding: utf-8

require 'sinatra'
require 'line/bot'

# 動作確認用
get '/' do
  'Hello World'
end

class HTTPProxyClient
  def http(uri)
    proxy_class = Net::HTTP::Proxy(ENV["FIXIE_URL_HOST"], ENV["FIXIE_URL_POST"], ENV["FIXIE_URL_USER"], ENV["FIXIE_URL_PASSWORD"])
    http = proxy_class.new(uri.host, uri.port)
    if uri.scheme == "https"
      http.use_ssl = true
    end
    http
  end

  def get(url, header = {})
    uri = URI(url)
    http(uri).get(uri.request_uri, header)
  end

  def post(url, payload, header = {})
    uri = URI(url)
    http(uri).post(uri.request_uri, payload, header)
  end
end

def client
  @client ||= Line::Bot::Client.new { |config|
    config.httpclient = HTTPProxyClient.new
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  events.each { |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        message = {
          type: 'text',
          text: event.message['text']
        }
        client.reply_message(event['replyToken'], message)
      when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
        response = client.get_message_content(event.message['id'])
        tf = Tempfile.open("content")
        tf.write(response.body)
      end
    end
  }

  "OK"
end
