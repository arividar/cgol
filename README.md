# Conway's Game of Life

A fast, interactive terminal-based implementation of Conway's Game of Life written in Zig.

## Features

- **Interactive Terminal Display**: Real-time visualization with ANSI colors and smooth animations
- **Configurable Parameters**: Customize grid size, generation count, and animation speed
- **Multiple Input Methods**: Command-line arguments, configuration file, or interactive prompts
- **Toroidal Topology**: Grid edges wrap around for seamless cellular automaton behavior
- **Efficient Implementation**: Double-buffered rendering with optimized memory management

## Quick Start

```bash
# Clone and build
git clone <repository-url>
cd cgol
zig build

# Run with default settings
zig build run

# Run with custom parameters
zig build run -- --height 30 --width 50 --generations 100 --delay 150
```

## Installation

### Prerequisites
- [Zig](https://ziglang.org/download/) 0.11.0 or later

### Building from Source

```bash
# Debug build (default)
zig build

# Release build
zig build -Doptimize=ReleaseSafe

# Install to zig-out/bin/
zig build install
```

### Running Tests

```bash
zig build test
```

## Usage

### Command Line Options

The application supports multiple ways to configure the simulation:

#### Named Arguments
```bash
cgol --height 40 --width 60 --generations 100 --delay 80
cgol --height=40 --width=60 --generations=100 --delay=80
```

#### Positional Arguments
```bash
cgol 40 60 100 80    # rows cols generations delay_ms
```

#### Interactive Mode
```bash
cgol --prompt-user-for-config    # Force prompts even if config exists
cgol -p                          # Short form
```

### Configuration File

Create a `cgol.toml` file in the working directory:

```toml
# Game of Life configuration
rows = 40
cols = 60
generations = 0    # 0 = infinite
delay_ms = 100
```

### Parameters

- **`--height <rows>`**: Grid height (default: 25)
- **`--width <cols>`**: Grid width (default: 80)
- **`--generations <n>`**: Number of generations to simulate (0 = infinite, default: 0)
- **`--delay <ms>`**: Delay between generations in milliseconds (default: 100)
- **`--help`**: Show help message

## Controls

- The simulation runs automatically once started
- Use `Ctrl+C` to exit
- Grid automatically adjusts to fit your terminal size

## Architecture

The project is organized into focused modules:

- **`main.zig`**: Application entry point and main game loop
- **`game.zig`**: Conway's Game of Life rules and grid operations
- **`config.zig`**: Configuration file parsing and management
- **`cli.zig`**: Command-line argument processing
- **`renderer.zig`**: Terminal rendering and ANSI escape sequences
- **`input.zig`**: User input handling for prompts
- **`constants.zig`**: Application constants and defaults

## Development

### Code Style

- Follow Zig conventions: `UpperCamelCase` for types, `lowerCamelCase` for functions/variables
- Use explicit types (`u8`, `usize`) and prefer `const` over `var`
- Format code with `zig fmt .` before committing
- Keep functions focused and separate I/O from pure logic

### Testing

- Add unit tests using inline `test` blocks
- Run tests locally with `zig build test`
- Focus tests on pure functions and edge cases

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following the code style guidelines
4. Add tests for new functionality
5. Run `zig fmt .` and `zig build test`
6. Submit a pull request

## License

[Add your license here]

## Acknowledgments

Conway's Game of Life was devised by mathematician John Horton Conway in 1970.