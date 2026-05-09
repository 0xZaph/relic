#!/usr/bin/env python3
"""
Build-time script to fetch the legendary binary for the current OS and architecture.
Downloads directly to the build directory.
"""

import os
import platform
import sys
from pathlib import Path
from urllib.request import Request, urlopen
from typing import Dict, Optional, Tuple

# Configuration
LEGENDARY_VERSION = '0.20.43'
LEGENDARY_REPO = 'Heroic-Games-Launcher/legendary'

# Mapping of platform and architecture to binary names
BINARY_MAPPING: Dict[str, Dict[str, str]] = {
    'x86_64': {
        'Linux': 'legendary_linux_x86_64',
        'Darwin': 'legendary_macOS_x86_64',
        'Windows': 'legendary_windows_x86_64.exe'
    },
    'arm64': {
        'Linux': 'legendary_linux_arm64',
        'Darwin': 'legendary_macOS_arm64'
    }
}


def get_platform_info() -> Tuple[str, str]:
    """Get the current platform and architecture."""
    system = platform.system()
    machine = platform.machine().lower()
    
    # Normalize architecture names
    if machine in ('amd64', 'x64'):
        machine = 'x86_64'
    elif machine in ('arm64', 'aarch64'):
        machine = 'arm64'
    
    return system, machine


def get_binary_filename(system: str, arch: str) -> Optional[str]:
    """Get the binary filename for the given platform and architecture."""
    if arch not in BINARY_MAPPING:
        print(f"Unsupported architecture: {arch}", file=sys.stderr)
        return None
    
    if system not in BINARY_MAPPING[arch]:
        print(f"Unsupported platform: {system} on {arch}", file=sys.stderr)
        return None
    
    return BINARY_MAPPING[arch][system]


def download_file(url: str, destination: Path) -> None:
    """Download a file from a URL to a destination path."""
    print(f"Downloading legendary from GitHub releases...")
    
    # Create parent directories if they don't exist
    destination.parent.mkdir(parents=True, exist_ok=True)
    
    # Download with custom User-Agent
    req = Request(url, headers={'User-Agent': 'SmiteBinaryUpdater/1.0'})
    
    with urlopen(req) as response:
        if response.status != 200:
            raise Exception(f"Failed to download {url}: HTTP {response.status}")
        
        with open(destination, 'wb') as f:
            f.write(response.read())
    
    print(f"Downloaded to: {destination}")


def main() -> int:
    """Main execution function."""
    # Get output directory from command line argument (provided by CMake)
    if len(sys.argv) < 2:
        print("Usage: fetch_legendary.py <output_directory>", file=sys.stderr)
        return 1
    
    output_dir = Path(sys.argv[1])
    
    # Get platform information
    system, arch = get_platform_info()
    print(f"Platform: {system} {arch}")
    
    # Get the binary filename for this platform
    binary_filename = get_binary_filename(system, arch)
    if not binary_filename:
        return 1
    
    # Construct download URL
    url = f"https://github.com/{LEGENDARY_REPO}/releases/download/{LEGENDARY_VERSION}/{binary_filename}"
    
    # Determine output filename (without .exe on non-Windows)
    output_filename = 'legendary.exe' if system == 'Windows' else 'legendary'
    output_path = output_dir / output_filename
    
    # Download the binary
    try:
        download_file(url, output_path)
    except Exception as e:
        print(f"Error downloading binary: {e}", file=sys.stderr)
        return 1
    
    # Make executable on Unix-like systems
    if system != 'Windows':
        os.chmod(output_path, 0o755)
        print(f"Set executable permissions")
    
    print(f"Legendary {LEGENDARY_VERSION} installed successfully!")
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
