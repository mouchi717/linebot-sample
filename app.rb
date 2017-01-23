#!/usr/local/bin/ruby
# encoding: utf-8

require 'sinatra'
require 'line/bot'
require 'date'

class Date
  (1..5).each { |n|
    define_method("第#{n}?") { (self.day.to_f / 7.to_f).ceil == n }
  }

  %w(日 月 火 水 木 金 土).each_with_index { |曜日, index|
    define_method("#{曜日}曜日?") { index == self.wday }
  }

  (1..5).each { |n|
    %w(日 月 火 水 木 金 土).each { |曜日|
      define_method("第#{n}#{曜日}曜日?") {
        self.send("第#{n}?") && self.send("#{曜日}曜日?")
      }
    }
  }
end

# 動作確認用
get '/' do
  'Hello World'
end

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

post '/callback' do
  body = request.body.read

  # RequestがLINEのPlatformから送られてきたかvalidateする
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

        messageBody = ''
        if event.message['text'] == 'ごみ' then

          明日 = Date.today + 1
          targets = []
          # targets << "可燃ゴミ" if 明日.月曜日? or 明日.木曜日?
          # targets << "不燃ゴミ" if 明日.第2土曜日?
          # targets << "資源ゴミ" if 明日.金曜日?
          targets << "ゴミ"

          messageBody = targets.empty? ? nil : "明日は%sの日です" % targets.map { |target| "「#{target}」" }.join
        else
          messageBody = event.message['text']
        end
        message = {
          type: 'text',
          text: messageBody
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
