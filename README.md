# Lua Delimited Text File Validator

A flexible and efficient validator for CSV and other delimited text files, capable of handling files up to 1GB in size. This validator has no external dependencies and runs with standard Lua.

## Features

- Custom delimiter support (single or multiple characters)
- Quoted string handling (both single and double quotes)
- Regular expression pattern validation for each field
- Optional header row support
- Maximum record length validation
- Efficient processing of large files
- No external dependencies

## Dependencies

- Lua 5.1 or later

## Usage

### Command Line

```bash
lua validate_file.lua <file_path> <config_path>
```

### Configuration File Format

The configuration file should be a Lua file that returns a table with the following structure:

```lua
return {
    delimiter = "string",        -- The string used to separate fields
    max_record_length = number,  -- Maximum allowed length for each record/line
    has_header = boolean,        -- Whether the file has a header row (optional)
    patterns = {                 -- Array of Lua patterns to validate each field
        "pattern1",
        "pattern2",
        -- ...
    }
}
```

Example configuration file:
```lua
-- config.lua
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
```

### Example Usage

1. Simple CSV validation:
```bash
lua validate_file.lua test_files/simple.csv test_files/simple_config.lua
```

2. Custom delimiter validation:
```bash
lua validate_file.lua test_files/custom_delim.txt test_files/custom_delim_config.lua
```

### Programmatic Usage

```lua
local validator = require("validator")

local content = "..." -- file contents
local config = {
    delimiter = ",",
    max_record_length = 100,
    has_header = true,
    patterns = {
        "^[A-Za-z' \",]+$",
        "^[0-9]+$",
        "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    }
}

local is_valid, message = validator.validate_file(content, config)
if is_valid then
    print("Validation successful!")
else
    print("Validation failed: " .. message)
end
```

## Test Files

The repository includes several test files:

1. `test_files/simple.csv` - A simple CSV file with header
2. `test_files/custom_delim.txt` - File with custom delimiter
3. `test_files/invalid.csv` - File with various validation errors

Each test file has a corresponding configuration file in Lua format (`.lua` extension).

# XML Validator with Namespace-Based Schema Validation

A Lua program that validates XML files against multiple schemas based on XML namespaces. The validator supports multiple namespaces in a single XML file and provides detailed error reporting.

## Features

- Namespace-based schema validation
- Support for multiple schemas in a single XML file
- Detailed error reporting
- Robust error handling
- Clear exit codes for automation

## Requirements

- Lua 5.1 or later
- Environment-provided XML and Schema handling functions:
  - `xml_load(filepath)`: Load XML file
  - `schema_load(filepath)`: Load schema file
  - `get_node_namespace(node)`: Get namespace of XML node
  - `get_next_node(xml_doc, current_node)`: Get next node in XML document
  - `validate_node(node, schema)`: Validate node against schema

## Usage

```bash
lua xml_validator.lua <xml_file> <namespace_mapping>
```

The namespace mapping should be provided as space-separated pairs of namespace URIs and schema file paths:

```bash
lua xml_validator.lua input.xml "http://example.com/ns1 schema1.xsd http://example.com/ns2 schema2.xsd"
```

## Exit Codes

- 0: Success (validation passed)
- 1: Invalid arguments
- 2: Invalid namespace mapping
- 3: XML file not found
- 4: Schema file not found
- 5: Invalid XML
- 6: Invalid schema
- 7: Validation failed
- 8: Unknown namespace
- 9: Internal error

## Example

```bash
# Validate an XML file with two namespaces
lua xml_validator.lua myfile.xml "http://example.com/ns1 schema1.xsd http://example.com/ns2 schema2.xsd"
```

## Testing

A test suite is provided in `test_xml_validator.lua`. To run the tests:

```bash
lua test_xml_validator.lua
```

The test suite includes:
- Valid input test
- Missing file test
- Invalid mapping format test
- No arguments test

## Error Messages

The validator provides detailed error messages for various failure cases:

```
Error parsing namespace mapping: Invalid mapping format: must be pairs of namespace and schema path

Failed to load schemas:
  Namespace 'http://example.com/ns1' (path: schema1.xsd): File not found

Validation errors:
  Namespace 'http://example.com/ns1': Element 'root' failed validation
```

## Implementation Notes

1. The validator processes the XML document node by node
2. Each node is validated against the schema corresponding to its namespace
3. All validation errors are collected and reported together
4. The program fails fast on critical errors (invalid arguments, missing files)
5. Memory efficient - processes one node at a time

## Environment Integration

The validator expects the following functions to be provided by the environment:

```lua
-- Load XML document
xml_load(filepath) -> xml_doc or nil, error_message

-- Load schema document
schema_load(filepath) -> schema or nil, error_message

-- Get namespace of current node
get_node_namespace(node) -> namespace or nil, error_message

-- Get next node in document
get_next_node(xml_doc, current_node) -> next_node or nil

-- Validate node against schema
validate_node(node, schema) -> boolean, error_message
``` 