local validator = require("validator")

local function assert_validation(content, config, expected_valid, expected_message)
    local is_valid, message = validator.validate_file(content, config)
    assert(is_valid == expected_valid, 
        string.format("Expected validation to be %s but got %s. Message: %s", 
        tostring(expected_valid), tostring(is_valid), message))
    if expected_message then
        assert(message == expected_message,
            string.format("Expected message '%s' but got '%s'", 
            expected_message, message))
    end
end

local tests = {
    -- Basic configuration tests
    test_invalid_config = function()
        assert_validation("test", nil, false, "Config must be a table")
        assert_validation("test", {}, false, "Invalid field delimiter configuration")
        assert_validation("test", {delimiter=","}, false, "Invalid patterns configuration")
    end,

    -- Basic field delimiter tests
    test_basic_field_delimiter = function()
        local config = {
            delimiter = ",",
            patterns = {"[%w]+", "[%d]+"}
        }
        assert_validation("word,123", config, true, "Validation successful")
        assert_validation("word|123", config, false)
    end,

    -- Custom record delimiter tests
    test_custom_record_delimiter = function()
        local config = {
            delimiter = ",",
            record_delimiter = "||",
            patterns = {"[%w]+", "[%d]+"}
        }
        assert_validation("word,123||test,456", config, true, "Validation successful")
        assert_validation("word,123\ntest,456", config, false)
    end,

    -- Quoted field tests
    test_quoted_fields = function()
        local config = {
            delimiter = ",",
            patterns = {".*", ".*"}
        }
        -- Test double quotes
        assert_validation('"field,with,comma",123', config, true, "Validation successful")
        -- Test single quotes
        assert_validation("'field,with,comma',123", config, true, "Validation successful")
        -- Test escaped quotes
        assert_validation('"field""with""quotes",123', config, true, "Validation successful")
        assert_validation("'field''with''quotes',123", config, true, "Validation successful")
    end,

    -- Whitespace handling tests
    test_whitespace_handling = function()
        local config = {
            delimiter = ",",
            patterns = {"[%w]+", "[%d]+"}
        }
        -- Test leading/trailing spaces in unquoted fields
        assert_validation("word  ,  123", config, true, "Validation successful")
        assert_validation("  word,123  ", config, true, "Validation successful")
        assert_validation('  word  ,  123  ', config, true, "Validation successful")
    end,

    -- Complex record delimiter tests
    test_complex_record_delimiters = function()
        local config = {
            delimiter = ",",
            record_delimiter = "###",
            patterns = {".*", ".*"}
        }
        -- Test multi-character delimiter
        assert_validation('"field,1",123###"field,2",456', config, true, "Validation successful")
        -- Test delimiter in quoted field
        assert_validation('"field###inside",123###"field,2",456', config, true, "Validation successful")
    end,

    -- Header handling tests
    test_header_handling = function()
        local config = {
            delimiter = ",",
            patterns = {"[%w]+", "[%d]+"},
            has_header = true
        }
        -- Valid with header
        assert_validation("Column1,Column2\nword,123", config, true, "Validation successful")
        -- Invalid data in header row shouldn't matter
        assert_validation("###,@@@\nword,123", config, true, "Validation successful")
    end,

    -- Empty field handling
    test_empty_fields = function()
        local config = {
            delimiter = ",",
            patterns = {".*", ".*"}
        }
        -- Empty quoted fields
        assert_validation('"",""', config, true, "Validation successful")
        -- Empty unquoted fields
        assert_validation(",", config, true, "Validation successful")
    end,

    -- Mixed quote styles and complex cases
    test_mixed_quotes_and_complex = function()
        local config = {
            delimiter = ",",
            patterns = {".*", ".*", ".*"}
        }
        -- Mix of quoted and unquoted fields
        assert_validation('"field,1",simple,123', config, true, "Validation successful")
        -- Quoted field with spaces around delimiter
        assert_validation('"field,1" , simple , "123"', config, true, "Validation successful")
        -- Complex quoted content
        assert_validation(
            '"field,with,commas" , "field with ""quotes"" inside" , "field with spaces"',
            config, true, "Validation successful"
        )
    end,

    -- Error cases
    test_error_cases = function()
        local config = {
            delimiter = ",",
            patterns = {"[%w]+", "[%d]+"}
        }
        -- Unclosed quote
        assert_validation('"unclosed,123', config, false)
        -- Wrong number of fields
        assert_validation("word", config, false)
        -- Pattern mismatch
        assert_validation("123,word", config, false)
    end,

    -- Test record delimiter in quoted fields
    test_record_delimiter_in_quotes = function()
        local config = {
            delimiter = ",",
            record_delimiter = "\n",
            patterns = {".*", ".*"}
        }
        -- Record delimiter in quoted field should be treated as normal character
        assert_validation('"field\nwith\nbreaks",123', config, true, "Validation successful")
    end,

    -- Test multiple record delimiters
    test_multiple_records = function()
        local config = {
            delimiter = ",",
            patterns = {"[%w]+", "[%d]+"}
        }
        local content = "word1,123\nword2,456\nword3,789"
        assert_validation(content, config, true, "Validation successful")
    end
}

-- Run all tests
local function run_tests()
    local passed = 0
    local failed = 0
    
    for name, test_func in pairs(tests) do
        io.write(string.format("Running %s... ", name))
        local success, error_msg = pcall(test_func)
        if success then
            io.write("PASSED\n")
            passed = passed + 1
        else
            io.write(string.format("FAILED: %s\n", error_msg))
            failed = failed + 1
        end
    end
    
    print(string.format("\nTest Summary:\nPassed: %d\nFailed: %d\nTotal: %d", 
        passed, failed, passed + failed))
    
    return failed == 0
end

-- Execute tests
local success = run_tests()
if not success then
    os.exit(1)
end