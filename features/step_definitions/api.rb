require 'json_like/rspec'
When /\AI request "(.*)"/ do | uri |
  @last_response = mock_get( uri )
end

Given /\AI have(?: also)? POSTed this to "(.*)":/ do | uri, json |
  mock_post( uri, MultiJson.load(json.to_s) )
end

When /\AI POST this to "(.*)":/ do | uri, json |
  @last_response = mock_post( uri, MultiJson.load(json.to_s) )
end

When /\AI PATCH this to "(.*)":/ do | uri, json |
  @last_response = mock_patch( uri, MultiJson.load(json.to_s) )
end

When /\AI follow the Location header/ do
  @last_response = mock_get( @last_response['Location'] )
end

Then /\Ashow me the response/ do
  puts @last_response.inspect
end

Then /\Athe response should be:/ do |string|
  expect(@last_response.body ).to eql(string)
end

Then /\Athe response should be like:/ do |string|
  expect(@last_response.body ).to JsonLike::RSpec.matcher(string)
end
