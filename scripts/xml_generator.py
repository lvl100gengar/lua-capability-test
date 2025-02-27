#!/usr/bin/env python3

import argparse
import os
import random
import string
import sys
from typing import Dict, List, Tuple, Optional
from lxml import etree
import math

class XMLGenerator:
    """Generates valid XML files based on XSD schemas with size control."""
    
    # Constants for size estimation and content generation
    AVERAGE_ELEMENT_OVERHEAD = 50  # Average bytes per element including tags and whitespace
    DEFAULT_STRING_LENGTH = 20
    DEFAULT_MIN_CHILDREN = 1
    DEFAULT_MAX_CHILDREN = 5
    
    def __init__(self, schema_path: str):
        """Initialize generator with schema."""
        self.schema_doc = etree.parse(schema_path)
        self.schema = etree.XMLSchema(self.schema_doc)
        self.nsmap = self.schema_doc.getroot().nsmap
        self.type_generators = self._create_type_generators()
        
        # Extract root element information
        self.root_element = self._find_root_element()
        if not self.root_element:
            raise ValueError("Could not determine root element from schema")
    
    def _create_type_generators(self) -> Dict:
        """Create generator functions for different XML schema types."""
        return {
            'string': self._generate_string,
            'integer': self._generate_integer,
            'decimal': self._generate_decimal,
            'date': self._generate_date,
            'dateTime': self._generate_datetime,
            'boolean': self._generate_boolean,
            'anyURI': self._generate_uri
        }
    
    def _find_root_element(self) -> Optional[etree.Element]:
        """Find the root element definition in the schema."""
        # Look for elements at the schema level
        root_elements = self.schema_doc.xpath(
            "//xs:element[@name]",
            namespaces={'xs': 'http://www.w3.org/2001/XMLSchema'}
        )
        if root_elements:
            return root_elements[0]
        return None
    
    def _calculate_target_elements(self, target_size_bytes: int) -> int:
        """Calculate number of elements needed to reach target size."""
        return math.ceil(target_size_bytes / self.AVERAGE_ELEMENT_OVERHEAD)
    
    def _generate_string(self, length: int = None) -> str:
        """Generate a random string."""
        if length is None:
            length = self.DEFAULT_STRING_LENGTH
        chars = string.ascii_letters + string.digits + ' '
        return ''.join(random.choice(chars) for _ in range(length))
    
    def _generate_integer(self) -> str:
        """Generate a random integer."""
        return str(random.randint(-1000000, 1000000))
    
    def _generate_decimal(self) -> str:
        """Generate a random decimal number."""
        return f"{random.uniform(-1000000, 1000000):.2f}"
    
    def _generate_date(self) -> str:
        """Generate a random date."""
        year = random.randint(1900, 2100)
        month = random.randint(1, 12)
        day = random.randint(1, 28)  # Simplified to avoid month/leap year complexity
        return f"{year:04d}-{month:02d}-{day:02d}"
    
    def _generate_datetime(self) -> str:
        """Generate a random datetime."""
        date = self._generate_date()
        hour = random.randint(0, 23)
        minute = random.randint(0, 59)
        second = random.randint(0, 59)
        return f"{date}T{hour:02d}:{minute:02d}:{second:02d}Z"
    
    def _generate_boolean(self) -> str:
        """Generate a random boolean."""
        return random.choice(['true', 'false'])
    
    def _generate_uri(self) -> str:
        """Generate a random URI."""
        domain = self._generate_string(10).lower()
        path = self._generate_string(15).lower()
        return f"http://{domain}.com/{path}"
    
    def _generate_element_content(self, element: etree.Element, depth: int = 0) -> str:
        """Generate content for an element based on its type."""
        type_name = element.get('type', 'string')
        base_type = type_name.split(':')[-1]
        
        generator = self.type_generators.get(base_type, self._generate_string)
        return generator()
    
    def _create_element(self, element_def: etree.Element, parent: etree.Element,
                       remaining_size: int, depth: int = 0) -> int:
        """Create an element and its children, tracking size."""
        if remaining_size <= 0 or depth > 100:  # Prevent infinite recursion
            return 0
        
        # Create the element
        name = element_def.get('name')
        if ':' in name:
            prefix, name = name.split(':')
        element = etree.SubElement(parent, name)
        
        # Generate content or child elements
        if element_def.get('type'):
            content = self._generate_element_content(element_def, depth)
            element.text = content
            size_used = len(content) + len(name) * 2 + 5  # Rough estimate of element size
        else:
            # Handle complex types
            size_used = len(name) * 2 + 5
            children_count = random.randint(
                self.DEFAULT_MIN_CHILDREN,
                min(self.DEFAULT_MAX_CHILDREN, remaining_size // self.AVERAGE_ELEMENT_OVERHEAD)
            )
            
            for _ in range(children_count):
                child_size = self._create_element(
                    element_def,
                    element,
                    (remaining_size - size_used) // children_count,
                    depth + 1
                )
                size_used += child_size
        
        return size_used
    
    def generate(self, target_size_bytes: int, output_path: str) -> None:
        """Generate XML file of approximately target_size_bytes."""
        # Create root element
        root = etree.Element(self.root_element.get('name'), nsmap=self.nsmap)
        doc = etree.ElementTree(root)
        
        # Calculate target number of elements
        target_elements = self._calculate_target_elements(target_size_bytes)
        
        # Generate content
        self._create_element(self.root_element, root, target_size_bytes)
        
        # Write to file with pretty printing
        doc.write(output_path, pretty_print=True, xml_declaration=True, encoding='UTF-8')
        
        # Verify size and schema validity
        actual_size = os.path.getsize(output_path)
        print(f"Generated XML file of size: {actual_size:,} bytes")
        
        try:
            doc = etree.parse(output_path)
            self.schema.assertValid(doc)
            print("Generated XML is valid according to schema")
        except etree.DocumentInvalid as e:
            print(f"Warning: Generated XML is not valid: {e}")
        except Exception as e:
            print(f"Error validating generated XML: {e}")

def main():
    parser = argparse.ArgumentParser(description='Generate valid XML files of specified size')
    parser.add_argument('schema', help='Path to XSD schema file')
    parser.add_argument('output', help='Path for output XML file')
    parser.add_argument('--size', type=int, default=1024,
                      help='Target size in bytes (default: 1KB)')
    
    args = parser.parse_args()
    
    try:
        generator = XMLGenerator(args.schema)
        generator.generate(args.size, args.output)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main() 