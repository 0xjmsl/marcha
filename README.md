# Marcha

A Windows script and task management application built with Flutter. Marcha provides a flexible multi-pane interface for developers and power users to orchestrate, monitor, and manage multiple processes and terminal instances efficiently.

## Features

### Task Management
- Create, edit, and organize tasks with customizable commands
- Group tasks for batch execution
- Task properties: name, executable, arguments, working directory, emoji icons, descriptions
- Placeholder support (`{{placeholderName}}`) for parameterized execution

### Automation Steps
Define automated interaction sequences for your tasks:
- Each step waits for a regex pattern in terminal output, then optionally sends a command
- Configurable timeout per step (default 30 seconds)
- Retry or skip on timeout
- Terminal becomes fully interactive after steps complete

### Multi-Terminal Dashboard
- Run multiple terminal instances simultaneously
- Full xterm emulation with PTY support (10,000-line history)
- ANSI color and escape sequence support

### Flexible Layouts
10 preset layouts to organize your workspace:
- Single pane, 2/3 columns, 2/3 rows
- Split layouts (2+1 configurations)
- 2x2 Grid

**Resizable Panes**: Drag dividers between panes to customize sizes. Ratios are saved per layout.

### Process Control
- Graceful shutdown with Ctrl+C, fallback to force kill
- Complete execution history with timestamps and exit codes
- Terminal output logging

### Theming & Customization
- Dark/Light mode
- Custom terminal color themes
- Text size presets (S/M/L/XL)

### Coming Soon
- **Resources Monitor** - CPU and memory monitoring
- **Project Config Files** - Load `marcha.config.json` from your projects for parameterized scripts

## Installation

### Prerequisites
- Flutter SDK (3.0+)
- Visual Studio with C++ build tools (for Windows)
- Windows 11 SDK

### Build from Source
```bash
# Clone the repository
git clone https://github.com/yourusername/marcha.git
cd marcha

# Get dependencies
flutter pub get

# Run in debug mode
flutter run -d windows

# Build release
flutter build windows --release
```

## Usage

### Creating Tasks
1. Click **Add Task** in the sidebar
2. Enter task name, executable (e.g., `python`, `npm`, `code`)
3. Add arguments and working directory
4. Choose an emoji icon
5. Optionally add automation steps (expand the Steps section)
6. Save and launch with the play button

### Using Automation Steps
1. Edit a task and expand the **Steps** section
2. Add steps with:
   - **Expect**: regex pattern to wait for in output
   - **Send**: command to send when pattern matches
3. Steps execute in order when the task starts
4. If a step times out, you can retry or skip it
5. After all steps complete, the terminal is fully interactive

### Layout Management
- Use the layout selector in the header to switch between 10 presets
- Drag the dividers between panes to resize them
- Your size preferences are saved per layout

## Data Storage

All user data is stored locally in `%APPDATA%\Marcha\` (typically `C:\Users\<YourUsername>\AppData\Roaming\Marcha\`):

| File                       | Description                                       |
| -------------------------- | ------------------------------------------------- |
| `marcha_settings.json`     | Application settings (theme, layout, pane ratios) |
| `templates.json`           | Your task/template definitions                    |
| `task_groups.json`         | Task group configurations                         |
| `display_order.json`       | Sidebar ordering                                  |
| `marcha_task_history.json` | Execution history                                 |
| `logs/`                    | Process output logs                               |

**Privacy Note**: Your tasks and configurations are stored only on your local machine. The repository does not include any user data, so you can safely share or publish your fork without exposing personal task configurations.

## Tech Stack

- **Framework**: Flutter (Dart)
- **Terminal**: xterm.dart + flutter_pty
- **Platform**: Windows 11

## Documentation

See the [docs](./docs/) folder for additional documentation.

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
