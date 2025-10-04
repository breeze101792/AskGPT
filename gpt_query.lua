local api_key = nil
local CONFIGURATION = nil

-- Attempt to load the api_key module. IN A LATER VERSION, THIS WILL BE REMOVED
local success, result = pcall(function() return require("api_key") end)
if success then
  api_key = result.key
else
  print("api_key.lua not found, skipping...")
end

-- Attempt to load the configuration module
success, result = pcall(function() return require("configuration") end)
if success then
  CONFIGURATION = result
else
  print("configuration.lua not found, skipping...")
end

-- Define your queryChatGPT function
local https = require("ssl.https")
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")
local socket = require("socket") -- Add socket for sleep function

local function queryChatGPT(message_history)
  -- Use api_key from CONFIGURATION or fallback to the api_key module
  local api_key_value = CONFIGURATION and CONFIGURATION.api_key or api_key
  local api_url = CONFIGURATION and CONFIGURATION.base_url or "https://api.openai.com/v1/chat/completions"
  local model = CONFIGURATION and CONFIGURATION.model or "gpt-4o-mini"
  local retry_limit = CONFIGURATION and CONFIGURATION.retry_limit or 5
  local retry_delay = CONFIGURATION and CONFIGURATION.retry_delay or 2 -- seconds

  -- Determine whether to use http or https
  local request_library = api_url:match("^https://") and https or http

  -- Start building the request body
  local requestBodyTable = {
    model = model,
    messages = message_history,
  }

  -- Add additional parameters if they exist
  if CONFIGURATION and CONFIGURATION.additional_parameters then
    for key, value in pairs(CONFIGURATION.additional_parameters) do
      requestBodyTable[key] = value
    end
  end

  -- Encode the request body as JSON
  local requestBody = json.encode(requestBodyTable)

  local headers = {
    ["Content-Type"] = "application/json",
    ["Authorization"] = "Bearer " .. api_key_value,
  }

  local responseBody = {}
  local res, code, responseHeaders

  local attempts = 0
  while attempts <= retry_limit do
    attempts = attempts + 1
    responseBody = {} -- Clear response body for each attempt

    -- Make the HTTP/HTTPS request
    res, code, responseHeaders = request_library.request {
      url = api_url,
      method = "POST",
      headers = headers,
      source = ltn12.source.string(requestBody),
      sink = ltn12.sink.table(responseBody),
    }

    if code == 200 then
      break -- Success, exit loop
    elseif attempts <= retry_limit and code == 503 then
      -- only retry when 503.
      print(string.format("Error querying ChatGPT API: %s. Retrying in %d seconds (attempt %d/%d)...", code, retry_delay, attempts, retry_limit + 1))
      socket.sleep(retry_delay)
    else
      -- we return the words to user, not just crash it.
      -- error("Error querying ChatGPT API after multiple retries: " .. code)
      return string.format("Error querying ChatGPT API: %s. Retrying attempt %d/%d.", code, attempts, retry_limit + 1)
    end
  end

  -- FIXME, ensure null check before return
  local response = json.decode(table.concat(responseBody))
  return response.choices[1].message.content
end

return queryChatGPT
