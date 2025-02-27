-- Configuration for custom_delim.txt
return {
    delimiter = "||",
    max_record_length = 200,
    has_header = true,
    patterns = {
        "^[A-Z0-9]+$",                  -- Product Code pattern
        "^[0-9]+(\\.[0-9]{1,2})?$",    -- Price pattern
        "^[0-9]+$",                     -- Quantity pattern
        "^[A-Za-z0-9,. \"||]+$"        -- Description pattern
    }
} 