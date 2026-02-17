#!/usr/bin/env python3
"""
Convert ABCD release to ReproSchema format.

Workflow:
  1. Clone NBDCtoolsData if needed
  2. Extract specific release from lst_dds.rda to CSV (using R)
  3. Update source_version in yaml config
  4. Convert CSV to ReproSchema format
  5. Cleanup temporary files

Usage:
  python scripts/convert.py --release 6.0
  python scripts/convert.py --release 6.0 --no-validate
  python scripts/convert.py --release 6.0 --keep-data
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

NBDC_REPO_URL = "https://github.com/nbdc-datahub/NBDCtoolsData.git"
NBDC_DATA_DIR = "NBDCtoolsData"
SCRIPT_DIR = Path(__file__).parent
DATA_DIR = Path("data")


def clone_nbdc_data():
    """Clone NBDCtoolsData repository if not present."""
    if os.path.exists(NBDC_DATA_DIR):
        print(f"Data directory '{NBDC_DATA_DIR}' already exists")
        return True

    print(f"Cloning {NBDC_REPO_URL}...")
    result = subprocess.run(
        ["git", "clone", "--depth", "1", NBDC_REPO_URL],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"Failed to clone repository: {result.stderr}")
        return False
    print("Clone complete")
    return True


def find_rda_path():
    """Find lst_dds.rda in either cloned or local dev location."""
    # Cloned location (inside repo)
    cloned_path = Path(NBDC_DATA_DIR) / "data" / "lst_dds.rda"
    if cloned_path.exists():
        return cloned_path

    # Local dev location (sibling directory)
    local_path = Path(__file__).parent.parent.parent / "NBDCtoolsData" / "data" / "lst_dds.rda"
    if local_path.exists():
        return local_path

    return None


def extract_release(rda_path: Path, release: str, output_csv: Path) -> bool:
    """Extract a specific release from lst_dds.rda to CSV using R."""
    r_script = SCRIPT_DIR / "extract_release.R"

    print(f"Extracting release {release} from {rda_path}...")
    cmd = ["Rscript", str(r_script), str(rda_path), release, str(output_csv)]
    print(f"Running: {' '.join(cmd)}")

    result = subprocess.run(cmd, capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print(f"Extraction failed: {result.stderr}")
        return False
    return True


def cleanup_nbdc_data():
    """Remove NBDCtoolsData directory."""
    if os.path.exists(NBDC_DATA_DIR):
        print(f"Cleaning up '{NBDC_DATA_DIR}'...")
        shutil.rmtree(NBDC_DATA_DIR)
        print("Cleanup complete")


def main():
    parser = argparse.ArgumentParser(description="Convert ABCD release to ReproSchema")
    parser.add_argument("--release", required=True, help="Release version (e.g., 6.0)")
    parser.add_argument(
        "--config", default="abcd_nbdc2rs.yaml", help="Path to config YAML"
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        default=True,
        help="Run validation after conversion (default: True)",
    )
    parser.add_argument(
        "--no-validate", action="store_false", dest="validate", help="Skip validation"
    )
    parser.add_argument(
        "--keep-data",
        action="store_true",
        default=False,
        help="Keep cloned data and extracted CSV after conversion",
    )
    args = parser.parse_args()

    # Ensure data directory exists
    DATA_DIR.mkdir(exist_ok=True)

    # Find or clone the RDA file
    rda_path = find_rda_path()
    cloned = False

    if rda_path is None:
        if not clone_nbdc_data():
            sys.exit(1)
        cloned = True
        rda_path = Path(NBDC_DATA_DIR) / "data" / "lst_dds.rda"

    # Output CSV path
    csv_path = DATA_DIR / f"abcd_{args.release}.csv"

    try:
        # Step 1: Extract release to CSV
        if not extract_release(rda_path, args.release, csv_path):
            sys.exit(1)

        # Step 2: Update yaml config with source_version from release argument
        yaml_path = Path(args.config)
        with open(yaml_path, 'r') as f:
            config = yaml.safe_load(f)
        config['source_version'] = args.release
        with open(yaml_path, 'w') as f:
            yaml.dump(config, f)
        print(f"Set source_version to {args.release}")

        # Step 3: Run reproschema conversion
        cmd = [
            "reproschema",
            "nbdc2reproschema",
            str(csv_path),
            args.config,
        ]
        print(f"Running: {' '.join(cmd)}")
        result = subprocess.run(cmd)
        if result.returncode != 0:
            print(f"Conversion failed with exit code {result.returncode}")
            sys.exit(result.returncode)

        # Step 4: Validate if requested (only validate the ABCD output directory)
        if args.validate:
            cmd = ["reproschema", "validate", "ABCD"]
            print(f"Running: {' '.join(cmd)}")
            result = subprocess.run(cmd)
            if result.returncode != 0:
                print(f"Validation failed with exit code {result.returncode}")
                sys.exit(result.returncode)

        print("Done!")

    finally:
        # Cleanup
        if not args.keep_data:
            if cloned:
                cleanup_nbdc_data()
            if csv_path.exists():
                print(f"Removing temporary CSV: {csv_path}")
                csv_path.unlink()


if __name__ == "__main__":
    main()
