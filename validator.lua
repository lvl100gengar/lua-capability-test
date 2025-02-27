local M = {}

-- Helper function to escape special regex characters
local function escape_pattern(text)
    return text:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

-- Helper function to create a pattern that matches quoted content
local function create_quoted_pattern(delimiter)
    local escaped_delim = escape_pattern(delimiter)
    -- Matches: "content" or 'content' including escaped quotes
    return [["(([^"]|\")*)"]] .. escaped_delim .. "?|'(([^']|\')*)']] .. escaped_delim .. "?"
end

-- Helper function to create a pattern that matches unquoted content
local function create_unquoted_pattern(delimiter)
    local escaped_delim = escape_pattern(delimiter)
    return string.format("([^%s]+)", escaped_delim)
end

-- Main validation function
function M.validate_file(content, config)
    if type(content) ~= "string" then
        return false, "Content must be a string"
    end
    
    if type(config) ~= "table" then
        return false, "Config must be a table"
    end
    
    -- Validate required config parameters
    local delimiter = config.delimiter
    local max_record_length = config.max_record_length
    local patterns = config.patterns
    local has_header = config.has_header or false
    
    if not delimiter or type(delimiter) ~= "string" or #delimiter == 0 then
        return false, "Invalid delimiter configuration"
    end
    
    if not max_record_length or type(max_record_length) ~= "number" or max_record_length <= 0 then
        return false, "Invalid max_record_length configuration"
    end
    
    if not patterns or type(patterns) ~= "table" or #patterns == 0 then
        return false, "Invalid patterns configuration"
    end
    
    -- Split content into lines
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    
    if #lines == 0 then
        return false, "Empty file"
    end
    
    -- Create patterns for matching fields
    local quoted_pattern = create_quoted_pattern(delimiter)
    local unquoted_pattern = create_unquoted_pattern(delimiter)
    local field_pattern = string.format("%s|%s|%s", quoted_pattern, unquoted_pattern, escape_pattern(delimiter))
    
    -- Process each line
    local start_idx = has_header and 2 or 1
    
    for i = start_idx, #lines do
        local line = lines[i]
        
        -- Check line length
        if #line > max_record_length then
            return false, string.format("Line %d exceeds maximum record length", i)
        end
        
        -- Parse fields
        local fields = {}
        local pos = 1
        local line_length = #line
        
        while pos <= line_length do
            local field_value = nil
            local quoted_value, quoted_value2, unquoted_value
            
            -- Try to match quoted or unquoted content
            quoted_value, pos = line:match(string.format("^%s()", quoted_pattern), pos)
            if not quoted_value then
                unquoted_value, pos = line:match(string.format("^%s()", unquoted_pattern), pos)
            end
            
            if quoted_value then
                field_value = quoted_value:sub(2, -2):gsub('\\"', '"'):gsub("\\'", "'")
            elseif unquoted_value then
                field_value = unquoted_value
            else
                -- Skip delimiter if found
                local delim_match = line:match("^" .. escape_pattern(delimiter) .. "()", pos)
                if delim_match then
                    pos = delim_match
                else
                    break
                end
            end
            
            if field_value then
                fields[#fields + 1] = field_value
            end
        end
        
        -- Validate number of fields matches number of patterns
        if #fields ~= #patterns then
            return false, string.format("Line %d has incorrect number of fields (expected %d, got %d)", i, #patterns, #fields)
        end
        
        -- Validate each field against its pattern
        for j, field in ipairs(fields) do
            if not field:match("^" .. patterns[j] .. "$") then
                return false, string.format("Field %d in line %d does not match pattern: %s", j, i, patterns[j])
            end
        end
    end
    
    return true, "Validation successful"
end

return M 