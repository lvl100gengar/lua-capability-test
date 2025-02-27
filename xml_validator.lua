#!/usr/bin/env lua

-- Error codes
local ERROR_CODES = {
    SUCCESS = 0,
    INVALID_ARGS = 1,
    INVALID_MAPPING = 2,
    FILE_NOT_FOUND = 3,
    SCHEMA_NOT_FOUND = 4,
    INVALID_XML = 5,
    INVALID_SCHEMA = 6,
    VALIDATION_FAILED = 7,
    UNKNOWN_NAMESPACE = 8,
    INTERNAL_ERROR = 9
}

-- Built-in schema mappings for common formats
local BUILTIN_SCHEMAS = {
    -- KML schemas (supports multiple versions)
    ["http://www.opengis.net/kml/2.2"] = "schemas/kml22.xsd",
    ["http://earth.google.com/kml/2.1"] = "schemas/kml21.xsd",
    ["http://earth.google.com/kml/2.0"] = "schemas/kml20.xsd",
    
    -- GML schemas (supports multiple versions)
    ["http://www.opengis.net/gml"] = "schemas/gml.xsd",          -- GML 2.0
    ["http://www.opengis.net/gml/3.2"] = "schemas/gml32.xsd",    -- GML 3.2
    ["http://www.opengis.net/gml/3.3"] = "schemas/gml33.xsd"     -- GML 3.3
}

-- Schema file paths relative to the validator installation directory
local SCHEMA_BASE_PATH = "./schemas"

-- Assumed environment-provided functions:
-- xml_load(filepath) -> xml_doc or nil, error_message
-- schema_load(filepath) -> schema or nil, error_message
-- get_node_namespace(node) -> namespace or nil, error_message
-- validate_node(node, schema) -> boolean, error_message

-- Helper function to detect file type from extension
local function get_file_type(filepath)
    local ext = filepath:match("%.([^%.]+)$")
    if ext then
        ext = ext:lower()
        if ext == "kml" then
            return "kml"
        elseif ext == "gml" then
            return "gml"
        end
    end
    return "xml"
end

-- Helper function to resolve schema path
local function resolve_schema_path(schema_path)
    -- If it's an absolute path or relative path starting with . or .., return as is
    if schema_path:match("^[/\\]") or schema_path:match("^%.%.?[/\\]") then
        return schema_path
    end
    
    -- Otherwise, resolve relative to SCHEMA_BASE_PATH
    return SCHEMA_BASE_PATH .. "/" .. schema_path
end

-- Parse namespace to schema mapping from string
local function parse_namespace_mapping(mapping_str)
    if type(mapping_str) ~= "string" then
        return nil, "Mapping must be a string"
    end
    
    local mapping = {}
    
    -- Start with built-in schemas
    for ns, schema in pairs(BUILTIN_SCHEMAS) do
        mapping[ns] = resolve_schema_path(schema)
    end
    
    local words = {}
    
    -- Split the string into words
    for word in mapping_str:gmatch("%S+") do
        table.insert(words, word)
    end
    
    -- Check if we have pairs of values
    if #words % 2 ~= 0 then
        return nil, "Invalid mapping format: must be pairs of namespace and schema path"
    end
    
    -- Create the mapping table
    for i = 1, #words, 2 do
        local namespace = words[i]
        local schema_path = words[i + 1]
        
        -- Allow overriding built-in schemas
        mapping[namespace] = schema_path
    end
    
    return mapping
end

-- Validate XML document against schema mapping
local function validate_xml(xml_doc, namespace_mapping)
    if not xml_doc then
        return ERROR_CODES.INVALID_XML, "Invalid XML document"
    end
    
    -- Get the document's namespace
    local doc_namespace, ns_err = get_node_namespace(xml_doc)
    if not doc_namespace then
        return ERROR_CODES.VALIDATION_FAILED, 
            string.format("Failed to get document namespace: %s", ns_err or "unknown error")
    end
    
    -- Check if we have a schema mapping for this namespace
    local schema_path = namespace_mapping[doc_namespace]
    if not schema_path then
        return ERROR_CODES.UNKNOWN_NAMESPACE,
            string.format("No schema mapping found for namespace: %s", doc_namespace)
    end
    
    -- Load the schema
    local schema, schema_err = schema_load(schema_path)
    if not schema then
        return ERROR_CODES.SCHEMA_NOT_FOUND,
            string.format("Failed to load schema for namespace '%s' (path: %s): %s",
                doc_namespace, schema_path, schema_err or "unknown error")
    end
    
    -- Validate the entire document against the schema
    local is_valid, val_err = validate_node(xml_doc, schema)
    if not is_valid then
        return ERROR_CODES.VALIDATION_FAILED,
            string.format("Validation failed for namespace '%s': %s",
                doc_namespace, val_err or "unknown error")
    end
    
    return ERROR_CODES.SUCCESS
end

-- Main function
local function main()
    -- Check arguments
    if #arg < 1 then
        io.stderr:write("Usage: lua xml_validator.lua <xml_file> [namespace_mapping]\n")
        io.stderr:write("Examples:\n")
        io.stderr:write("  lua xml_validator.lua input.kml\n")
        io.stderr:write("  lua xml_validator.lua input.gml\n")
        io.stderr:write("  lua xml_validator.lua input.xml \"http://example.com/ns1 schema1.xsd\"\n")
        return ERROR_CODES.INVALID_ARGS
    end
    
    local xml_path = arg[1]
    local mapping_str = arg[2] or ""
    
    -- Parse namespace mapping
    local namespace_mapping, mapping_err = parse_namespace_mapping(mapping_str)
    if not namespace_mapping then
        io.stderr:write(string.format("Error parsing namespace mapping: %s\n", mapping_err))
        return ERROR_CODES.INVALID_MAPPING
    end
    
    -- Load XML document
    local xml_doc, xml_err = xml_load(xml_path)
    if not xml_doc then
        io.stderr:write(string.format("Error loading XML file: %s\n", xml_err or "unknown error"))
        return ERROR_CODES.FILE_NOT_FOUND
    end
    
    -- Validate XML
    local result_code, error_msg = validate_xml(xml_doc, namespace_mapping)
    if result_code ~= ERROR_CODES.SUCCESS then
        io.stderr:write(error_msg .. "\n")
    else
        local file_type = get_file_type(xml_path)
        io.stdout:write(string.format("Successfully validated %s file\n", file_type:upper()))
    end
    
    return result_code
end

-- Run main function and handle any unexpected errors
local ok, result = pcall(main)
if not ok then
    io.stderr:write(string.format("Internal error: %s\n", result))
    os.exit(ERROR_CODES.INTERNAL_ERROR)
end

os.exit(result) 