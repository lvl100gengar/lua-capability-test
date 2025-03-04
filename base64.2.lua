-- Precomputed base64 lookup table
local b64_lookup = {}
do
    local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
    for i = 1, #b64 do
        b64_lookup[b64:sub(i, i)] = i - 1
    end
end

-- Optimized base64 decode
local function base64_decode(input)
    local output = ""
    local buffer = 0
    local bits = 0
    for i = 1, #input do
        local char = input:sub(i, i)
        local value = b64_lookup[char]
        if value and value < 64 then
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

-- Main function with alignment handling
local function find_keywords_in_base64_doc(document, search_keywords)
    local last_decoded = ""
    local last_end = 0

    for b64_str in document:gmatch("[A-Za-z0-9+/=]+") do
        if #b64_str >= 8 and #b64_str % 4 == 0 then
            local b64_start = document:find(b64_str, 1, true)
            local b64_end = b64_start + #b64_str - 1
            local decoded = base64_decode(b64_str)

            -- Check the individual decoded string
            if search_keywords(decoded) then
                return true
            end

            -- Check across boundary if adjacent to previous sequence
            if last_end + 1 == b64_start and last_decoded ~= "" then
                local combined = last_decoded .. decoded
                if search_keywords(combined) then
                    return true
                end
            end

            last_decoded = decoded
            last_end = b64_end
        end
    end
    return false
end

-- Test cases
local function run_tests()
    local function search_keywords(text)
        return text:find("key", 1, true) ~= nil -- Keyword "key" (min length 3)
    end

    -- Test 1: Aligned keyword in single block
    local doc1 = "Prefix S2V5SGVsbG8= Suffix" -- "KeyHello"
    assert(find_keywords_in_base64_doc(doc1, search_keywords) == true, "Test 1 failed")

    -- Test 2: No keyword
    local doc2 = "Prefix SGVsbG8= Suffix" -- "Hello"
    assert(find_keywords_in_base64_doc(doc2, search_keywords) == false, "Test 2 failed")

    -- Test 3: Keyword split across adjacent blocks (offset 0)
    local doc3 = "Prefix S2V5 YmFzZQ== Suffix" -- "Ke" + "ybase"
    assert(find_keywords_in_base64_doc(doc3, search_keywords) == true, "Test 3 failed")

    -- Test 4: Keyword split across adjacent blocks (offset 1)
    local doc4 = "Prefix QmFrZXk= Suffix" -- "Bakey" (key at offset 2)
    assert(find_keywords_in_base64_doc(doc4, search_keywords) == true, "Test 4 failed")

    -- Test 5: Keyword split across adjacent blocks (offset 2)
    local doc5 = "Prefix QmFz S2V5 Suffix" -- "Bas" + "Key"
    assert(find_keywords_in_base64_doc(doc5, search_keywords) == true, "Test 5 failed")

    -- Test 6: Non-adjacent blocks (no false positives)
    local doc6 = "Prefix S2V5 YmFzZQ== Suffix" -- "Ke" + " [space] " + "ybase"
    assert(find_keywords_in_base64_doc(doc6, search_keywords) == false, "Test 6 failed")

    -- Test 7: Short sequence skipped
    local doc7 = "Prefix S2V5=== Suffix" -- "Key" but too short (< 8)
    assert(find_keywords_in_base64_doc(doc7, search_keywords) == false, "Test 7 failed")

    print("All tests passed!")
end

run_tests()