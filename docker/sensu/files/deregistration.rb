#!/usr/bin/env ruby
#

require "json"
require "rest-client"

# Load the Sensu event data from STDIN
event = JSON.parse(STDIN.read, :symbolize_names => true)

sensu_api_client_url = "http://127.0.0.1:4567/clients/#{event[:client][:name]}"
response = RestClient.delete( sensu_api_client_url )
puts response
