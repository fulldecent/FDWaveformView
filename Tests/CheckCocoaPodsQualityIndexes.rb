#!/bin/ruby
#
# The validates that all controllable quality metrics receive maximum score
#
# Metrics are at: https://guides.cocoapods.org/making/quality-indexes.html
# Your modifiers are at: https://cocoadocs-api-cocoapods-org.herokuapp.com/pods/FDWaveformView/stats
# Your raw data is at: http://metrics.cocoapods.org/api/v1/pods/FDWaveformView
#

require "json"
require "uri"
require "net/http"

uri = URI.parse('https://cocoadocs-api-cocoapods-org.herokuapp.com/pods/FDWaveformView/stats')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true if uri.scheme == 'https'
request = Net::HTTP::Get.new uri
response = http.request(request)

if !response.is_a? Net::HTTPOK
  puts "HTTP fetching error!"
  exit 1
end

passing = true
for metric in JSON.parse(response.body)['metrics']
  if ['Verified Owner', 'Very Popular', 'Popular'].include? metric['title']
    puts "SKIPPED\tYou cannot control: " + metric['title']
    next
  end
  if metric['modifier'] >= 0
    if metric['applies_for_pod']
      puts "GOOD\tEarned points for: " + metric['title']
    else
      puts "BAD\tMissed points for: " + metric['title']
      passing = false
    end
  else
    if metric['applies_for_pod']
      puts "BAD\tLost points for: " + metric['title']
      passing = false
    else
      puts "GOOD\tAvoided penalty for: " + metric['title']
    end
  end
end

exit passing ? 0 : 1
