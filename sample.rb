#!/usr/local/bin/ruby
# encoding: utf-8

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


明日 = Date.today + 1
targets = []
targets << "可燃ゴミ" if 明日.月曜日? or 明日.木曜日?
targets << "不燃ゴミ" if 明日.第2土曜日?
targets << "資源ゴミ" if 明日.金曜日?

message = targets.empty? ? nil : "明日は%sの日です" % targets.map { |target| "「#{target}」" }.join
