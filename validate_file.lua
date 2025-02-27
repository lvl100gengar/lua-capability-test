#!/usr/bin/env lua

local validator = require("validator")

-- Print usage information
local function print_usage()
    print("Usage: lua validate_file.lua <file_path> <config_path>")
    print("  file_path: Path to the delimited text file to validate")
    print("  config_path: Path to the Lua configuration file")
    os.exit(1)
end

-- Main execution
local function main()
    -- Check command line arguments
    if #arg ~= 2 then
        print_usage()
    end
    
    local file_path = arg[1]
    local config_path = arg[2]
    
    -- Load and execute config file
    local config_chunk, load_err = loadfile(config_path)
    if not config_chunk then
        print(string.format("Error: Cannot load config file '%s': %s", config_path, load_err))
        os.exit(1)
    end
    
    local config
    local success, result = pcall(config_chunk)
    if not success then
        print(string.format("Error: Cannot execute config file: %s", result))
        os.exit(1)
    end
    
    if type(result) ~= "table" then
        print("Error: Config file must return a table")
        os.exit(1)
    end
    
    config = result
    
    -- Read input file
    local input_file = io.open(file_path, "r")
    if not input_file then
        print(string.format("Error: Cannot open input file '%s'", file_path))
        os.exit(1)
    end
    
    local content = input_file:read("*a")
    input_file:close()
    
    -- Validate the file
    local is_valid, message = validator.validate_file(content, config)
    
    if is_valid then
        print("Validation successful!")
        os.exit(0)
    else
        print(string.format("Validation failed: %s", message))
        os.exit(1)
    end
end

-- Run the main function
main() 