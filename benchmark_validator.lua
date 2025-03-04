local validator = require("validator")

-- Utility functions for generating test data
local function random_string(length, quoted)
    local chars = {}
    for i = 1, length do
        chars[i] = string.char(math.random(65, 90))  -- Use only A-Z for predictable sizes
    end
    local str = table.concat(chars)
    return quoted and ('"' .. str .. '"') or str
end

local function random_number()
    return string.format("%06d", math.random(1, 1000000))
end

local function random_date()
    return string.format("%04d-%02d-%02d", 
        math.random(1900, 2024),
        math.random(1, 12),
        math.random(1, 28))
end

local function random_email(quoted)
    local domains = {"example.com", "test.org", "benchmark.net", "sample.edu"}
    local email = string.format("%s@%s", random_string(10, false), domains[math.random(1, #domains)])
    return quoted and ('"' .. email .. '"') or email
end

-- Calculate average field sizes
local function calculate_field_sizes(quoted)
    local sizes = {
        string = quoted and 22 or 20,  -- 20 chars (+ 2 quotes if quoted)
        number = 6,                    -- 6 digits
        date = quoted and 12 or 10,    -- YYYY-MM-DD (+ 2 quotes if quoted)
        email = quoted and 27 or 25    -- email (+ 2 quotes if quoted)
    }
    return sizes
end

-- Function to estimate record size
local function estimate_record_size(num_fields, field_types, field_sizes)
    local size = num_fields - 1  -- Count delimiters
    for i = 1, num_fields do
        local field_type = field_types[((i-1) % #field_types) + 1]
        size = size + field_sizes[field_type]
    end
    return size + 1  -- Add newline character
end

-- Function to generate a test record with specified number of fields
local function generate_record(num_fields, field_types, quote_probability)
    local fields = {}
    for i = 1, num_fields do
        local field_type = field_types[((i-1) % #field_types) + 1]
        local should_quote = math.random() < quote_probability
        local value
        
        if field_type == "string" then
            value = random_string(20, should_quote)
        elseif field_type == "number" then
            value = random_number()
        elseif field_type == "date" then
            value = random_date()
        elseif field_type == "email" then
            value = random_email(should_quote)
        end
        fields[i] = value
    end
    return table.concat(fields, ",")
end

-- Function to generate patterns for validation
local function generate_patterns(num_fields, field_types)
    local patterns = {}
    for i = 1, num_fields do
        local field_type = field_types[((i-1) % #field_types) + 1]
        if field_type == "string" then
            patterns[i] = ".*"
        elseif field_type == "number" then
            patterns[i] = "[%d]+"
        elseif field_type == "date" then
            patterns[i] = "%d%d%d%d%-%d%d%-%d%d"
        elseif field_type == "email" then
            patterns[i] = "[%w%.]+@[%w%.]+"
        end
    end
    return patterns
end

-- Function to parse size string to bytes
local function parse_size(size_str)
    local num = tonumber(size_str:match("%d+"))
    local unit = size_str:match("%a+")
    if unit == "KB" then
        return num * 1024
    elseif unit == "MB" then
        return num * 1024 * 1024
    elseif unit == "GB" then
        return num * 1024 * 1024 * 1024
    end
    return num
end

-- Benchmark configurations
local size_configs = {
    {name = "1MB", size = "1MB"},
    {name = "10MB", size = "10MB"},
    {name = "100MB", size = "100MB"},
    {name = "300MB", size = "300MB"},
    {name = "500MB", size = "500MB"}
}

local field_configs = {
    {name = "10 fields", count = 10},
    {name = "25 fields", count = 25},
    {name = "50 fields", count = 50},
    {name = "100 fields", count = 100}
}

local quote_configs = {
    {name = "No quotes", probability = 0.0},
    {name = "25% quoted", probability = 0.25},
    {name = "50% quoted", probability = 0.50},
    {name = "100% quoted", probability = 1.0}
}

-- Function to get current memory usage in bytes
local function get_memory_usage()
    return collectgarbage("count") * 1024
end

-- Function to format memory size
local function format_memory(bytes)
    local units = {"B", "KB", "MB", "GB"}
    local size = bytes
    local unit_index = 1
    while size >= 1024 and unit_index < #units do
        size = size / 1024
        unit_index = unit_index + 1
    end
    return string.format("%.2f %s", size, units[unit_index])
end

-- Function to check if system can handle content size
local function check_memory_for_size(target_bytes)
    collectgarbage("collect")
    local start_mem = get_memory_usage()
    
    -- Try to allocate a small test string to verify memory availability
    local test_size = math.min(target_bytes, 100 * 1024 * 1024) -- Test with 100MB or target size
    local test_str = string.rep("x", test_size)
    if not test_str then
        return false, "Failed to allocate test memory block"
    end
    test_str = nil
    collectgarbage("collect")
    
    -- Check if we have enough headroom (need ~2.5x the content size for safe operation)
    local required_memory = target_bytes * 2.5
    local available_memory = 2^31 - start_mem -- Conservative estimate for 32-bit Lua
    
    return available_memory >= required_memory, format_memory(required_memory)
end

-- Function to generate test content in memory
local function generate_test_content(num_rows, num_fields, field_types, quote_prob)
    local content = {}
    local total_size = 0
    
    -- Generate header
    local header = {}
    for i = 1, num_fields do
        header[i] = string.format("Field%d", i)
    end
    content[1] = table.concat(header, ",")
    total_size = #content[1] + 1 -- +1 for newline
    
    -- Generate records
    for i = 1, num_rows do
        local record = generate_record(num_fields, field_types, quote_prob)
        content[i + 1] = record
        total_size = total_size + #record + 1 -- +1 for newline
    end
    
    return table.concat(content, "\n"), total_size
end

-- Function to run a specific benchmark configuration
local function run_benchmark_configuration(size_target, num_fields, quote_prob, field_types)
    local field_sizes = calculate_field_sizes(quote_prob > 0)
    local target_bytes = parse_size(size_target)
    local record_size = estimate_record_size(num_fields, field_types, field_sizes)
    local num_rows = math.ceil(target_bytes / record_size)
    
    -- Check if we have enough memory
    local can_proceed, mem_required = check_memory_for_size(target_bytes)
    if not can_proceed then
        return {
            is_valid = false,
            message = string.format("Insufficient memory. Required: %s", mem_required)
        }
    end
    
    -- Generate test content
    collectgarbage("collect")
    local start_mem = get_memory_usage()
    local content, actual_size = generate_test_content(num_rows, num_fields, field_types, quote_prob)
    local gen_mem = get_memory_usage() - start_mem
    
    if not content then
        return {
            is_valid = false,
            message = "Failed to generate test content"
        }
    end
    
    -- Create validation config
    local validation_config = {
        delimiter = ",",
        patterns = generate_patterns(num_fields, field_types),
        has_header = true
    }
    
    -- Measure validation time
    collectgarbage("collect")
    local validate_start_mem = get_memory_usage()
    local start_validate = os.clock()
    local is_valid, message = validator.validate_file(content, validation_config)
    local validate_time = os.clock() - start_validate
    local validate_mem = get_memory_usage() - validate_start_mem
    
    -- Clean up
    content = nil
    collectgarbage("collect")
    
    return {
        size = actual_size,
        validate_time = validate_time,
        is_valid = is_valid,
        message = message,
        num_rows = num_rows,
        num_fields = num_fields,
        processing_speed = (actual_size / 1024 / 1024) / validate_time,
        records_per_second = num_rows / validate_time,
        fields_per_second = (num_rows * num_fields) / validate_time,
        generation_memory = gen_mem,
        validation_memory = validate_mem
    }
end

-- Function to print table header
local function print_table_header(columns)
    local header = "| "
    local separator = "|-"
    for _, col in ipairs(columns) do
        header = header .. string.format("%-20s | ", col)
        separator = separator .. string.rep("-", 21) .. "|-"
    end
    print(separator)
    print(header)
    print(separator)
end

-- Function to print table row
local function print_table_row(values)
    local row = "| "
    for _, value in ipairs(values) do
        row = row .. string.format("%-20s | ", tostring(value))
    end
    print(row)
end

-- Main benchmark function
local function run_benchmarks()
    local field_types = {"string", "number", "date", "email"}
    
    print("\nCSV Validator Performance Benchmark")
    print("=================================")
    print("Memory Usage Format: Generation / Validation")
    
    -- Test 1: Impact of file size
    print("\n1. File Size Impact")
    print_table_header({"Size", "Valid Time(s)", "Speed(MB/s)", "Memory Usage", "Status"})
    for _, size_config in ipairs(size_configs) do
        local result = run_benchmark_configuration(
            size_config.size, 25, 0.25, field_types
        )
        print_table_row({
            size_config.name,
            result.is_valid and string.format("%.3f", result.validate_time) or "FAILED",
            result.is_valid and string.format("%.2f", result.processing_speed) or "-",
            result.is_valid and string.format("%s/%s", 
                format_memory(result.generation_memory),
                format_memory(result.validation_memory)) or "-",
            result.is_valid and "OK" or result.message
        })
    end
    print("|-" .. string.rep("-", 21 * 5 + 5) .. "|")
    
    -- Test 2: Impact of field count
    print("\n2. Field Count Impact")
    print_table_header({"Fields", "Valid Time(s)", "Speed(MB/s)", "Memory Usage", "Status"})
    for _, field_config in ipairs(field_configs) do
        local result = run_benchmark_configuration(
            "100MB", field_config.count, 0.25, field_types
        )
        print_table_row({
            tostring(field_config.count),
            result.is_valid and string.format("%.3f", result.validate_time) or "FAILED",
            result.is_valid and string.format("%.2f", result.processing_speed) or "-",
            result.is_valid and string.format("%s/%s", 
                format_memory(result.generation_memory),
                format_memory(result.validation_memory)) or "-",
            result.is_valid and "OK" or result.message
        })
    end
    print("|-" .. string.rep("-", 21 * 5 + 5) .. "|")
    
    -- Test 3: Impact of quoted fields
    print("\n3. Quote Usage Impact")
    print_table_header({"Quote %", "Valid Time(s)", "Speed(MB/s)", "Memory Usage", "Status"})
    for _, quote_config in ipairs(quote_configs) do
        local result = run_benchmark_configuration(
            "100MB", 25, quote_config.probability, field_types
        )
        print_table_row({
            string.format("%.0f%%", quote_config.probability * 100),
            result.is_valid and string.format("%.3f", result.validate_time) or "FAILED",
            result.is_valid and string.format("%.2f", result.processing_speed) or "-",
            result.is_valid and string.format("%s/%s", 
                format_memory(result.generation_memory),
                format_memory(result.validation_memory)) or "-",
            result.is_valid and "OK" or result.message
        })
    end
    print("|-" .. string.rep("-", 21 * 5 + 5) .. "|")
end

-- Set random seed for reproducible results
math.randomseed(os.time())

-- Run the benchmarks
run_benchmarks() 