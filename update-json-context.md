# Update JSON File Creation Process

## Overview
The update JSON file creation process is part of the ReVanced Builder's update mechanism. The system creates update JSON files for each module/APK that is built, which are then used to track and manage updates.

## Key Components

### 1. File Naming Convention
- Update JSON files follow the naming pattern: `{table_name}-update.json`
- The table name is converted to lowercase
- Example: `youtube-update.json`

### 2. Creation Process
The update JSON file is created during the build process in `utils.sh`:

```bash
# In utils.sh
local upj="${table,,}-update.json"  # Convert table name to lowercase and append -update.json
```

The process involves:
1. A temporary directory is created for the module template:
```bash
base_template=$(mktemp -d -p "$TEMP_DIR")
cp -a $MODULE_TEMPLATE_DIR/. "$base_template"
```

2. The update JSON filename is generated based on the table name
3. The file is referenced in the module properties:
```bash
module_prop \
    "${args[module_prop_name]}" \
    "${app_name} ${args[rv_brand]}" \
    "${version} (patches: ${rv_patches_ver%%.rvp})" \
    "${app_name} ${args[rv_brand]} Magisk module" \
    "https://raw.githubusercontent.com/${GITHUB_REPOSITORY-}/update/${upj}" \
    "$base_template"
```

### 3. GitHub Workflow Integration
The update process is managed through GitHub Actions in `.github/workflows/build.yml`:

```yaml
# Update config step
- name: Update config
  if: ${{ inputs.from_ci }}
  run: |
    if git checkout origin/update build.md; then
      UPDATE_CFG=$(./build.sh config.toml --config-update)
      if [ "$UPDATE_CFG" ]; then
        echo "$UPDATE_CFG" > config.json
      fi
    fi

# Build step
- name: Build modules/APKs
  run: if [ -f "config.json" ]; then ./build.sh config.json; else ./build.sh config.toml; fi
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

# Create dummy update JSON if none exist
- name: Create dummy update JSON
  run: find . -name "*-update.json" | grep . || : >dummy-update.json
```

### 4. Update Branch Handling
The update branch is used to store the latest build information. The process involves:

```yaml
# In .github/workflows/build.yml
- name: Checkout
  uses: actions/checkout@v4
  with:
    fetch-depth: 0
    submodules: true
```

### 5. File Structure
The update JSON files contain:
```json
{
    "version": "string",
    "versionCode": "number",
    "zipUrl": "string",
    "changelog": "string",
    "timestamp": "number",
    "compatibility": {
        "minApi": "number",
        "maxApi": "number"
    }
}
```

## Workflow Steps
1. Checkout update branch
2. Update configuration if needed
3. Build modules/APKs
4. Generate update JSON files
5. Store files in update branch
6. Create build documentation

## Important Files
- `utils.sh`: Contains the core logic for creating update JSON files
- `.github/workflows/build.yml`: Manages the GitHub Actions workflow
- `build.sh`: Main build script that orchestrates the process
- `config.toml`: Configuration file that defines build parameters
- `config.json`: Generated configuration file for updates

## File Setup
The update JSON files are set up in the following locations:
1. During build: `$TEMP_DIR/{table_name}-update.json`
2. Final location: `update/{table_name}-update.json` in the update branch
3. GitHub repository: `https://raw.githubusercontent.com/{owner}/{repo}/update/{table_name}-update.json` 