# ConfigMgr-Task-Sequence-Monitor

A tool to monitor and report on task sequence executions in ConfigMgr.

## Configuration

`Config.example.xml` is the tracked template. The application creates the local `Config.xml` when settings are saved; the local file is ignored by Git.

## Fork & Acknowledgments

This repository is a **fork of a fork**:
* **Current Repository:** [andrewblunt/ConfigMgr-Task-Sequence-Monitor](https://github.com/andrewblunt/ConfigMgr-Task-Sequence-Monitor)
* **Upstream Fork:** [stephannn/ConfigMgr-Task-Sequence-Monitor](https://github.com/stephannn/ConfigMgr-Task-Sequence-Monitor)
* **Original Project:** Created by **Trevor Jones** / [SMSAgent Software](https://github.com/SMSAgentSoftware/ConfigMgr-Task-Sequence-Monitor)

Special thanks and full credit to **Trevor Jones** (SMSAgent) for developing the original tool, and **stephannn** for upstream contributions and enhancements.

## Changelog

### 2.0
- Modernized the native WPF interface and visual styling
- Improved refresh and report reliability
- Removed the MahApps.Metro runtime dependency
- Added a Git-ignored local configuration file with a tracked example template
- Improved window sizing, selection highlighting, and general UI responsiveness

### 1.9.1
- Improved UI responsiveness during refresh operations
- Improved report generation reliability with incomplete data
- Restored consistent DataGrid selection highlighting

### 1.9
- Security, performance, and code quality improvements
- MDT Options removed
- UI/layout tweaks
- Added "Show Skipped Steps" toggle option
- Added "Grey Disabled Steps" setting in Settings window
- Added device count display next to ComputerName drop-down

### 1.8
- Changed Hostname to GUID to select specific device. Before unknown devices could not be selected separately.

### 1.7
- Using XML instead of Registry
- Exported XAML Part
- Changed SQL queries to grab more information
