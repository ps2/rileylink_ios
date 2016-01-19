#!/usr/bin/env ruby

require 'open-uri'
require 'json'

if ARGV.count < 2
  puts "Usage: readlog.rb <NSURL> <count>"
  exit -1
end 

entries = JSON.parse(open("#{ARGV[0]}/api/v1/entries.json?find[type]=logs&count=#{ARGV[1]}").read)

entries = entries.sort_by {|e| e["dateString"]}

#puts entries.map {|e| e["dateString"]}.inspect

entries.each do |e|
  e["entries"].each do |line|
    puts line
  end
end
