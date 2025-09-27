# Save Files Directory

This directory contains Conway's Game of Life save files (`.cgol` format).

## File Format

Save files use TOML format with the following structure:

```toml
# Conway's Game of Life Save File
version = "1.0"

[metadata]
saved_at = "1703123456"
description = "Optional description of this save"
original_pattern = "pattern_filename.rle"

[game_state]
current_generation = 150
rows = 40
cols = 60
generations = 1000
delay_ms = 100

[grid_data]
encoding = "rle_compressed"
data = "40b$5bo$3bo$4b2o$..."
```

## Usage

### Save Current State
```bash
cgol --save checkpoint.cgol --description "My checkpoint"
cgol --save saves/backup.cgol
```

### Load Saved State
```bash
cgol --load checkpoint.cgol
cgol --load saves/backup.cgol
```

### Auto-save
```bash
cgol --auto-save-every 100 --save-prefix "auto_backup_"
```

### List Saves
```bash
cgol --list-saves
```

## Grid Compression

Grid data is compressed using Run-Length Encoding (RLE) format:
- `o` = live cell
- `b` = dead cell  
- Numbers prefix indicate repetition count
- `$` indicates end of row

Example: `3b2o$2bo$` represents:
```
   oo
  o
```

## File Naming

- Use `.cgol` extension for save files
- Auto-saves include timestamp and optional prefix
- Files can be stored in subdirectories