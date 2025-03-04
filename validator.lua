local M = {}

-- Helper function to escape special regex characters
local function escape_pattern(text)
    return text:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

-- Helper function to trim whitespace from a string
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end


-- Helper function to parse a field, handling quoted content
local function parse_field(line, pos, field_delimiter, line_length)
    -- Skip leading whitespace
    while pos <= line_length and line:sub(pos, pos):match("%s") do
        pos = pos + 1
    end
    
    -- Check if we're at the end of the line
    if pos > line_length then
        return "", pos
    end
    
    local first_char = line:sub(pos, pos)
    -- Check for quoted field
    if first_char == '"' or first_char == "'" then
        local quote = first_char
        local value_start = pos + 1
        local i = value_start
        
        while i <= line_length do
            if line:sub(i, i) == quote then
                if i < line_length and line:sub(i + 1, i + 1) == quote then
                    -- Skip double quote
                    i = i + 2
                else
                    -- End of quoted field
                    local field_value = line:sub(value_start, i - 1):gsub(quote..quote, quote)
                    pos = i + 1
                    -- Skip trailing whitespace and delimiter
                    while pos <= line_length and line:sub(pos, pos):match("%s") do
                        pos = pos + 1
                    end
                    if pos <= line_length and line:sub(pos, pos + #field_delimiter - 1) == field_delimiter then
                        pos = pos + #field_delimiter
                    end
                    return field_value, pos
                end
            else
                i = i + 1
            end
        end
        
        -- Reached end of line without closing quote
        return nil, pos
    else
        -- Unquoted field
        local delim_pos = string.find(line, field_delimiter, pos, true)
        if delim_pos then
            local field_value = trim(line:sub(pos, delim_pos - 1))
            return field_value, delim_pos + #field_delimiter
        else
            -- Last field in line
            local field_value = trim(line:sub(pos))
            return field_value, line_length + 1
        end
    end
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
    local field_delimiter = config.delimiter
    local record_delimiter = config.record_delimiter or "\n"
    local record_delimiter_length = #record_delimiter
    local is_single_char_record_delim = record_delimiter_length == 1
    local patterns = config.patterns
    local has_header = config.has_header or false
    
    if not field_delimiter or type(field_delimiter) ~= "string" or #field_delimiter == 0 then
        return false, "Invalid field delimiter configuration"
    end
    
    if not record_delimiter or type(record_delimiter) ~= "string" or record_delimiter_length == 0 then
        return false, "Invalid record delimiter configuration"
    end
    
    if not patterns or type(patterns) ~= "table" or #patterns == 0 then
        return false, "Invalid patterns configuration"
    end
    
    -- Precompile patterns for better performance
    local compiled_patterns = {}
    for i, pattern in ipairs(patterns) do
        compiled_patterns[i] = "^" .. pattern .. "$"
    end
    
    -- Process content
    local pos = 1
    local content_length = #content
    local record_number = 1
    local in_quotes = false
    local quote_char = nil
    local record_start = 1
    local records_processed = 0
    
    -- Skip header if present
    if has_header then
        local header_end = content:find(record_delimiter, pos, true)
        if header_end then
            pos = header_end + record_delimiter_length
            record_start = pos
            record_number = 2
        else
            -- Single line file with header
            pos = content_length + 1
            record_start = pos
            record_number = 2
        end
    end
    
    local function validate_record(record, record_num)
        if #record == 0 then return true end
        
        local fields = {}
        local field_pos = 1
        local record_length = #record
        
        -- Parse fields
        while field_pos <= record_length do
            local field_value, new_pos = parse_field(record, field_pos, field_delimiter, record_length)
            if field_value == nil and new_pos == field_pos then
                return false, string.format("Invalid quoted field in record %d", record_num)
            end
            fields[#fields + 1] = field_value
            field_pos = new_pos
        end
        
        -- Handle trailing empty field if record ends with delimiter
        if record:sub(-#field_delimiter) == field_delimiter then
            fields[#fields + 1] = ""
        end
        
        -- Validate number of fields
        if #fields ~= #patterns then
            return false, string.format("Record %d has incorrect number of fields (expected %d, got %d)", 
                record_num, #patterns, #fields)
        end
        
        -- Validate fields against patterns
        for j = 1, #fields do
            local field = fields[j]
            if #field > 0 and not field:match(compiled_patterns[j]) then
                return false, string.format("Field %d in record %d does not match pattern: %s", 
                    j, record_num, patterns[j])
            end
        end
        
        return true
    end
    





    if is_single_char_record_delim then
        while pos <= content_length do
            local char = content:sub(pos, pos)
            -- Handle quotes (same as current code)
            if (char == '"' or char == "'") then
                if not in_quotes then
                    in_quotes = true
                    quote_char = char
                elseif char == quote_char then
                    if pos < content_length and content:sub(pos + 1, pos + 1) == char then
                        pos = pos + 1
                    else
                        in_quotes = false
                        quote_char = nil
                    end
                end
            end
            -- Fast check for single-character delimiter
            if not in_quotes and char == record_delimiter then
                local record = content:sub(record_start, pos - 1)
                local is_valid, error_msg = validate_record(record, record_number)
                if not is_valid then
                    return false, error_msg
                end
                records_processed = records_processed + 1
                record_start = pos + 1  -- Single char, so +1
                record_number = record_number + 1
            end
            pos = pos + 1
        end
    else
        -- Existing multi-character delimiter loop
        -- (keep your current code here)
        while pos <= content_length do
            local char = content:sub(pos, pos)
            
            -- Handle quotes
            if (char == '"' or char == "'") then
                if not in_quotes then
                    in_quotes = true
                    quote_char = char
                elseif char == quote_char then
                    if pos < content_length and content:sub(pos + 1, pos + 1) == char then
                        -- Skip escaped quote
                        pos = pos + 1
                    else
                        in_quotes = false
                        quote_char = nil
                    end
                end
            end
            
            -- Check for record delimiter when not in quotes
            if not in_quotes and pos <= (content_length - record_delimiter_length + 1) then
                if content:sub(pos, pos + record_delimiter_length - 1) == record_delimiter then
                    -- Process record
                    local record = content:sub(record_start, pos - 1)
                    local is_valid, error_msg = validate_record(record, record_number)
                    if not is_valid then
                        return false, error_msg
                    end
                    
                    records_processed = records_processed + 1
                    record_start = pos + record_delimiter_length
                    record_number = record_number + 1
                    pos = pos + record_delimiter_length - 1
                end
            end
            
            pos = pos + 1
        end
    end




    
    -- Process final record if exists
    if record_start <= content_length then
        local record = content:sub(record_start)
        local is_valid, error_msg = validate_record(record, record_number)
        if not is_valid then
            return false, error_msg
        end
        records_processed = records_processed + 1
    end
    
    -- Check if we processed any records
    if records_processed == 0 and (not has_header or content_length == 0) then
        return false, "Empty file"
    end
    
    return true, "Validation successful"
end

return M 