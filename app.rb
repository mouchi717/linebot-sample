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

get '/push' do

  今日 = Date.today
  targets = []
  targets << "可燃ゴミ" if 今日.月曜日? or 今日.木曜日?
  targets << "不燃ゴミ" if 今日.第2土曜日?
  targets << "資源ゴミ" if 今日.金曜日?

  messageBody = targets.empty? ? "今日はゴミの日ちゃうで" : "今日は%sの日やで" % targets.map { |target| "「#{target}」" }.join
  message = {
    type: 'text',
    text: messageBody
  }
  response = client.push_message(ENV["UID_OUCHI"], message)
  p response
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
        GARBAGE_WORDS = ["ごみ", "ゴミ"]
        if GARBAGE_WORDS.include?(event.message['text']) then
          targetDate = Date.today.to_time.hour.between?(5, 9) ? Date.today : Date.today + 1
          targets = []
          targets << "可燃ゴミ" if targetDate.月曜日? or targetDate.木曜日?
          targets << "不燃ゴミ" if targetDate.第2土曜日?
          targets << "資源ゴミ" if targetDate.金曜日?

          messageBody = targetDate.to_time == Date.today.to_time ? "今日" : "明日"
          messageBody << targets.empty? ? "はゴミの日ちゃうで" : "は%sの日やで" % targets.map { |target| "「#{target}」" }.join
          message = {
            type: 'text',
            text: messageBody
          }
          client.reply_message(event['replyToken'], message)
        else
          message = {
            type: 'text',
            text: 'すまんな。"ごみ"or"ゴミ"以外対応してないんや。'
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    end
  }
  "OK"
end
