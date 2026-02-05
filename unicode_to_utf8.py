#!/usr/bin/env python3
"""
Convert Unicode code points to UTF-8 hex escape sequences for Lua strings
Usage:
    python3 unicode_to_utf8.py U+EC5F
    python3 unicode_to_utf8.py EC5F
    python3 unicode_to_utf8.py 0xEC5F
    python3 unicode_to_utf8.py 60511 (decimal)
"""

import sys

def unicode_to_utf8_hex(code_point_str):
    """Convert Unicode code point to UTF-8 hex escape sequence"""
    # Parse input
    code_point_str = code_point_str.strip().upper()
    
    try:
        if code_point_str.startswith('U+'):
            code = int(code_point_str[2:], 16)
        elif code_point_str.startswith('0X'):
            code = int(code_point_str, 16)
        elif code_point_str.startswith('0x'):
            code = int(code_point_str, 16)
        else:
            # Try hex first, then decimal
            try:
                code = int(code_point_str, 16)
            except ValueError:
                code = int(code_point_str, 10)
    except ValueError:
        print(f"Error: Cannot parse '{code_point_str}'")
        return None
    
    # Validate range
    if code < 0 or code > 0x10FFFF:
        print(f"Error: Code point U+{code:04X} out of valid Unicode range")
        return None
    
    # Convert to UTF-8
    try:
        char = chr(code)
        utf8_bytes = char.encode('utf-8')
        hex_escape = ''.join(f'\\x{b:02x}' for b in utf8_bytes)
        return hex_escape, code, char
    except Exception as e:
        print(f"Error: {e}")
        return None

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 unicode_to_utf8.py <code_point>")
        print("Examples:")
        print("  python3 unicode_to_utf8.py U+EC5F")
        print("  python3 unicode_to_utf8.py EC5F")
        print("  python3 unicode_to_utf8.py 0xEC5F")
        print("  python3 unicode_to_utf8.py 60511")
        sys.exit(1)
    
    for arg in sys.argv[1:]:
        result = unicode_to_utf8_hex(arg)
        if result:
            hex_escape, code, char = result
            print(f"U+{code:04X} ({code}) '{char}':")
            print(f"  UTF-8 hex: {hex_escape}")
            print(f"  Lua string: \"text {hex_escape} more\"")
            print()

if __name__ == "__main__":
    main()
