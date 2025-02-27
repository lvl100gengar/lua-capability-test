#!/usr/bin/env lua

-- Mock environment functions for testing
local function xml_load(filepath)
    if filepath == "test.xml" then
        return {
            type = "mock_xml_doc",
            namespace = "http://example.com/ns1",
            content = "<root xmlns='http://example.com/ns1'><element>test</element></root>"
        }
    elseif filepath == "mixed_namespaces.xml" then
        return {
            type = "mock_xml_doc",
            namespace = "http://example.com/ns1",
            content = "<root xmlns='http://example.com/ns1'><element xmlns='http://example.com/ns2'>test</element></root>"
        }
    elseif filepath == "test.kml" then
        return {
            type = "mock_xml_doc",
            namespace = "http://www.opengis.net/kml/2.2",
            content = "<kml xmlns='http://www.opengis.net/kml/2.2'><Placemark><name>Test</name></Placemark></kml>"
        }
    elseif filepath == "test.gml" then
        return {
            type = "mock_xml_doc",
            namespace = "http://www.opengis.net/gml/3.2",
            content = "<gml:FeatureCollection xmlns:gml='http://www.opengis.net/gml/3.2'><gml:featureMember/></gml:FeatureCollection>"
        }
    elseif filepath == "old_kml.kml" then
        return {
            type = "mock_xml_doc",
            namespace = "http://earth.google.com/kml/2.1",
            content = "<kml xmlns='http://earth.google.com/kml/2.1'><Placemark><name>Test</name></Placemark></kml>"
        }
    end
    return nil, "File not found: " .. filepath
end

local function schema_load(filepath)
    -- Mock successful schema loading for built-in schemas
    if filepath:match("^./schemas/") then
        return {
            type = "mock_schema",
            path = filepath
        }
    elseif filepath:match("%.xsd$") then
        return {
            type = "mock_schema",
            path = filepath
        }
    end
    return nil, "Invalid schema file: " .. filepath
end

local function get_node_namespace(node)
    if not node then return nil, "Invalid node" end
    
    if not node.namespace then
        return nil, "Invalid node"
    end
    return node.namespace
end

local function validate_node(doc, schema)
    if not doc or not schema then
        return false, "Invalid document or schema"
    end
    
    -- Mock validation - succeed for valid namespace, fail for mixed namespaces
    if doc.content and doc.content:find('xmlns=\'http://example.com/ns2\'') then
        return false, "Document contains elements from different namespace"
    end
    
    return true
end

-- Make these functions available globally for the validator
_G.xml_load = xml_load
_G.schema_load = schema_load
_G.get_node_namespace = get_node_namespace
_G.validate_node = validate_node

-- Test cases
local function run_tests()
    local tests = {
        {
            name = "Valid document test",
            args = {
                "test.xml",
                "http://example.com/ns1 schema1.xsd"
            },
            expected_code = 0
        },
        {
            name = "Missing file test",
            args = {
                "nonexistent.xml",
                "http://example.com/ns1 schema1.xsd"
            },
            expected_code = 3
        },
        {
            name = "Invalid mapping format test",
            args = {
                "test.xml",
                "http://example.com/ns1"
            },
            expected_code = 2
        },
        {
            name = "No arguments test",
            args = {},
            expected_code = 1
        },
        {
            name = "Mixed namespaces document test",
            args = {
                "mixed_namespaces.xml",
                "http://example.com/ns1 schema1.xsd"
            },
            expected_code = 7  -- Should fail validation due to mixed namespaces
        },
        {
            name = "Unknown namespace test",
            args = {
                "test.xml",
                "http://example.com/ns2 schema2.xsd"
            },
            expected_code = 8  -- Unknown namespace
        },
        {
            name = "KML 2.2 validation test",
            args = {
                "test.kml"
            },
            expected_code = 0
        },
        {
            name = "GML 3.2 validation test",
            args = {
                "test.gml"
            },
            expected_code = 0
        },
        {
            name = "KML 2.1 backward compatibility test",
            args = {
                "old_kml.kml"
            },
            expected_code = 0
        },
        {
            name = "Custom schema override test",
            args = {
                "test.kml",
                "http://www.opengis.net/kml/2.2 custom_kml.xsd"
            },
            expected_code = 0
        }
    }
    
    print("Running XML validator tests...")
    print("------------------------------")
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        print(string.format("\nTest: %s", test.name))
        
        -- Reset command line arguments
        arg = test.args
        
        -- Run the validator
        local ok, result = pcall(function()
            dofile("xml_validator.lua")
        end)
        
        -- Check result
        if ok and result == test.expected_code then
            print("✓ PASSED")
            passed = passed + 1
        else
            print("✗ FAILED")
            print(string.format("  Expected exit code: %d", test.expected_code))
            print(string.format("  Actual result: %s", ok and result or "error: " .. tostring(result)))
            failed = failed + 1
        end
    end
    
    print("\nTest Summary")
    print("------------")
    print(string.format("Passed: %d", passed))
    print(string.format("Failed: %d", failed))
    print(string.format("Total:  %d", passed + failed))
    
    return failed == 0
end

-- Run the tests
local success = run_tests()
os.exit(success and 0 or 1) 