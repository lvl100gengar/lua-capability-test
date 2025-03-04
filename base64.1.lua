-- Precomputed base64 lookup table for speed
local b64_lookup = {}
do
    local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
    for i = 1, #b64 do
        b64_lookup[b64:sub(i, i)] = i - 1
    end
end

-- Optimized base64 decode function
local function base64_decode(input)
    local output = ""
    local buffer = 0
    local bits = 0
    for i = 1, #input do
        local char = input:sub(i, i)
        local value = b64_lookup[char]
        if value and value < 64 then -- Skip padding ('=' is 64)
            buffer = buffer * 64 + value
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                output = output .. string.char(buffer >> bits)
                buffer = buffer % (1 << bits)
            end
        end
    end
    return output
end

-- Main function to search for keywords in base64-encoded parts of a string
local function find_keywords_in_base64_doc(document, search_keywords)
    -- Iterate over all potential base64 sequences
    for b64_str in document:gmatch("[A-Za-z0-9+/=]+") do
        -- Minimum length check: 8 base64 chars decode to >= 3 bytes (24 bits)
        -- (4 chars = 3 bytes, but we need to ensure a 3-char keyword fits)
        if #b64_str >= 8 and #b64_str % 4 == 0 then
            local decoded = base64_decode(b64_str)
            if search_keywords(decoded) then
                return true -- Keyword found
            end
        end
    end
    return false -- No keywords found
end

-- Example usage
local document = "Hello VGhpcyBpcyBhIHNlY3JldA== world" -- "This is a secret"
local function search_keywords(text)
    -- Dummy implementation (min keyword length = 3)
    return text:find("secret", 1, true) ~= nil
end

local result = find_keywords_in_base64_doc(document, search_keywords)
print("Keywords found: " .. tostring(result)) -- Prints "true"