#!/usr/bin/env python3
"""Convert a Yarn v1 `yarn.lock` file into JSON.

Usage: yarnlock_to_json.py [--debug] [input-yarn-lock]
If no file is provided, reads from stdin.
--debug: Enable debug output to stderr
"""
import sys
import json
from pathlib import Path


def clean_key(key):
    """Remove escaped quotes and other unnecessary escaping from keys"""
    return key.replace('\\"', '"').replace('\\\\', '\\')


def parse_yarn_lock(lines):
    result = {}
    current_keys = None
    current = None
    current_section = None

    def finish_entry():
        nonlocal current_keys, current
        if not current_keys or current is None:
            return
        for k in current_keys:
            # Clean up escaped quotes in keys before storing
            clean_k = clean_key(k)
            result[clean_k] = current

    i = 0
    while i < len(lines):
        line = lines[i].rstrip('\n')
        if not line.strip():
            finish_entry()
            current_keys = None
            current = None
            current_section = None
            i += 1
            continue

        if not line.startswith(' '):
            finish_entry()
            header = line.strip()
            if header.endswith(':'):
                header = header[:-1]
            keys = [clean_key(h.strip()) for h in header.split(',')]
            current_keys = keys
            current = {}
            current_section = None
            i += 1
            continue

        stripped = line.lstrip()
        indent = len(line) - len(stripped)

        if stripped.endswith(':'):
            sec = stripped[:-1]
            current_section = sec
            if sec == 'dependencies':
                current.setdefault('dependencies', {})
            elif sec == 'optionalDependencies':
                current.setdefault('optionalDependencies', {})
            else:
                current_section = sec
            i += 1
            continue

        parts = stripped.split(None, 1)
        if not parts:
            i += 1
            continue
        key = parts[0]
        val = parts[1].strip() if len(parts) > 1 else ''
        if val.startswith('"') and val.endswith('"'):
            val = val[1:-1]

        if current_section in ('dependencies', 'optionalDependencies') and indent >= 4:
            dep_parts = stripped.split(None, 1)
            dep_name = dep_parts[0]
            dep_ver = dep_parts[1].strip() if len(dep_parts) > 1 else ''
            if dep_ver.startswith('"') and dep_ver.endswith('"'):
                dep_ver = dep_ver[1:-1]
            container = 'optionalDependencies' if current_section == 'optionalDependencies' else 'dependencies'
            current.setdefault(container, {})[dep_name] = dep_ver
        else:
            current[key] = val

        i += 1

    finish_entry()
    return result


def main(argv):
    # Parse arguments for debug flag and input file
    debug = False
    input_file = None
    
    for arg in argv[1:]:
        if arg == '--debug':
            debug = True
        elif not input_file:
            input_file = arg
        else:
            print("Usage: yarnlock_to_json.py [--debug] [input-yarn-lock]", file=sys.stderr)
            print("If no file is provided, reads from stdin.", file=sys.stderr)
            return 2

    if input_file:
        # Read from file
        infile = Path(input_file)
        if not infile.is_file():
            print(f"Error: input file '{infile}' not found.", file=sys.stderr)
            return 3
        text = infile.read_text(encoding='utf-8').splitlines(True)
    else:
        # Read from stdin
        text = sys.stdin.read().splitlines(True)

    # Handle empty input
    if not text or not any(line.strip() for line in text):
        print("{}")
        return 0

    parsed = parse_yarn_lock(text)
    
    # Debug: Print parsed data info to stderr (only if debug flag is set)
    if debug:
        print(f"DEBUG: Parsed {len(parsed)} entries", file=sys.stderr)
        if parsed:
            sample_key = list(parsed.keys())[0]
            sample_value = parsed[sample_key]
            print(f"DEBUG: Sample key: {sample_key}", file=sys.stderr)
            print(f"DEBUG: Sample value: {sample_value}", file=sys.stderr)
            print(f"DEBUG: Value type: {type(sample_value)}", file=sys.stderr)
    
    # Extract only package name and version to reduce data size
    simplified = {}
    for key, value in parsed.items():
        # Extract package name (everything before the first @)
        package_name = key.split('@')[0] if '@' in key else key
        # Remove leading/trailing quotes and backslashes from package name
        package_name = package_name.strip(' "\'\\')
        
        # Skip the _metadata package
        if package_name == '_metadata':
            continue
            
        # Extract version from the value object (try both 'version' and 'version:' keys)
        if isinstance(value, dict):
            version = value.get('version', '') or value.get('version:', '')
        else:
            version = str(value)
        
        # Debug: Print extraction info for first few entries (only if debug flag is set)
        if debug and len(simplified) < 3:
            print(f"DEBUG: Processing key='{key}' -> name='{package_name}', version='{version}'", file=sys.stderr)
        
        # Only include if we have both name and version
        if package_name and version:
            simplified[package_name] = version
    
    # Debug: Print final count (only if debug flag is set)
    if debug:
        print(f"DEBUG: Simplified to {len(simplified)} entries", file=sys.stderr)
    
    # Print simplified JSON to stdout
    print(json.dumps(simplified, indent=2, sort_keys=True))
    return 0

if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
