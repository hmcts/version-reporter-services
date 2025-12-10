#!/usr/bin/env python3
"""Convert a Yarn v1 `yarn.lock` file into JSON.

Usage: yarnlock_to_json.py input-yarn-lock
"""
import sys
import json
from pathlib import Path


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
            result[k] = current

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
            keys = [h.strip() for h in header.split(',')]
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
    if len(argv) != 2:
        print("Usage: yarnlock_to_json.py input-yarn-lock", file=sys.stderr)
        return 2

    infile = Path(argv[1])

    if not infile.is_file():
        print(f"Error: input file '{infile}' not found.", file=sys.stderr)
        return 3

    text = infile.read_text(encoding='utf-8').splitlines(True)
    parsed = parse_yarn_lock(text)
    
    # Print JSON to stdout so it can be captured by bash
    print(json.dumps(parsed, indent=2, sort_keys=True))
    return 0

if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
