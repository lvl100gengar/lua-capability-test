-- Configuration for simple.csv
return {
    delimiter = ",",
    max_record_length = 100,
    has_header = true,
    patterns = {
        "^[A-Za-z' \",]+$",     -- Name pattern
        "^[0-9]+$",             -- Age pattern
        "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"  -- Email pattern
    }
} 