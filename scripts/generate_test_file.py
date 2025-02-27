#!/usr/bin/env python3

import argparse
import random
import string
import re
import os
from typing import List, Dict, Any

class TestDataGenerator:
    def __init__(self, config_file: str):
        """Initialize the generator with a Lua config file."""
        self.config = self._parse_lua_config(config_file)
        self.pattern_generators = self._create_pattern_generators()
        
    def _parse_lua_config(self, config_file: str) -> Dict[str, Any]:
        """Parse the Lua config file and extract relevant information."""
        with open(config_file, 'r') as f:
            content = f.read()
            
        # Extract values using simple parsing (avoiding Lua dependencies)
        config = {}
        
        # Extract delimiter
        delimiter_match = re.search(r'delimiter\s*=\s*["\'](.+?)["\']', content)
        if delimiter_match:
            config['delimiter'] = delimiter_match.group(1)
            
        # Extract max_record_length
        length_match = re.search(r'max_record_length\s*=\s*(\d+)', content)
        if length_match:
            config['max_record_length'] = int(length_match.group(1))
            
        # Extract has_header
        header_match = re.search(r'has_header\s*=\s*(true|false)', content)
        if header_match:
            config['has_header'] = header_match.group(1) == 'true'
            
        # Extract patterns
        patterns = []
        pattern_section = re.search(r'patterns\s*=\s*{(.+?)}', content, re.DOTALL)
        if pattern_section:
            pattern_content = pattern_section.group(1)
            # Find all patterns, handling both single and double quoted strings
            pattern_matches = re.finditer(r'["\']((?:\\.|[^"\'\\])+)["\']', pattern_content)
            for match in pattern_matches:
                # Only add if it looks like a pattern (not a comment)
                if '^' in match.group(1):
                    patterns.append(match.group(1))
        
        config['patterns'] = patterns
        return config
    
    def _create_pattern_generators(self) -> List[callable]:
        """Create generator functions for each pattern."""
        generators = []
        
        for pattern in self.config['patterns']:
            if re.search(r'\^[A-Za-z\' \",]+\$', pattern):  # Name pattern
                generators.append(lambda: self._generate_name())
            elif re.search(r'\^[0-9]+\$', pattern):  # Integer pattern
                generators.append(lambda: str(random.randint(18, 80)))
            elif '@' in pattern:  # Email pattern
                generators.append(lambda: self._generate_email())
            elif r'\.[0-9]{1,2}' in pattern:  # Price pattern
                generators.append(lambda: f"{random.uniform(10, 1000):.2f}")
            elif re.search(r'\^[A-Z0-9]+\$', pattern):  # Product code pattern
                generators.append(lambda: self._generate_product_code())
            else:  # Generic text pattern
                generators.append(lambda: self._generate_text(20))
        
        return generators
    
    def _generate_name(self) -> str:
        """Generate a random name."""
        first_names = ['John', 'Jane', 'Robert', 'Mary', 'William', 'Elizabeth', 'James', 'Sarah']
        last_names = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis']
        
        if random.random() < 0.3:  # 30% chance of quoted name with comma
            name = f'"{random.choice(last_names)}, {random.choice(first_names)}"'
        else:
            name = f'{random.choice(first_names)} {random.choice(last_names)}'
        return name
    
    def _generate_email(self) -> str:
        """Generate a random email address."""
        domains = ['example.com', 'test.com', 'company.com', 'mail.com']
        name = ''.join(random.choices(string.ascii_lowercase, k=random.randint(5, 10)))
        return f"{name}@{random.choice(domains)}"
    
    def _generate_product_code(self) -> str:
        """Generate a random product code."""
        letters = ''.join(random.choices(string.ascii_uppercase, k=3))
        numbers = ''.join(random.choices(string.digits, k=3))
        return f"{letters}{numbers}"
    
    def _generate_text(self, max_length: int) -> str:
        """Generate random text of given maximum length."""
        length = random.randint(5, max_length)
        return ''.join(random.choices(string.ascii_letters + ' ', k=length))
    
    def generate_record(self) -> str:
        """Generate a single record using the configured patterns."""
        fields = [generator() for generator in self.pattern_generators]
        return self.config['delimiter'].join(fields)
    
    def generate_file(self, output_file: str, target_size_mb: float) -> None:
        """Generate a file of approximately the specified size in MB."""
        target_size_bytes = int(target_size_mb * 1024 * 1024)
        current_size = 0
        
        with open(output_file, 'w', encoding='utf-8') as f:
            # Write header if configured
            if self.config['has_header']:
                header = self.config['delimiter'].join([f"Field{i+1}" for i in range(len(self.config['patterns']))])
                f.write(header + '\n')
                current_size = len(header) + 1
            
            # Write records until we reach or exceed the target size
            while current_size < target_size_bytes:
                record = self.generate_record()
                f.write(record + '\n')
                current_size += len(record) + 1
        
        actual_size_mb = os.path.getsize(output_file) / (1024 * 1024)
        print(f"Generated file '{output_file}' of size {actual_size_mb:.2f} MB")

def main():
    parser = argparse.ArgumentParser(description='Generate test files for Lua validator')
    parser.add_argument('config', help='Path to Lua configuration file')
    parser.add_argument('output', help='Path to output file')
    parser.add_argument('size', type=float, help='Target file size in MB')
    
    args = parser.parse_args()
    
    generator = TestDataGenerator(args.config)
    generator.generate_file(args.output, args.size)

if __name__ == '__main__':
    main() 