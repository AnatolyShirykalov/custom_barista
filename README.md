# Custom Barista Status Bar

A custom status bar implementation for i3 window manager based on [barista](https://github.com/soumya92/barista), featuring system monitoring modules with modern styling.

## Features

- **System Monitoring**: CPU load, memory usage, temperature, and disk space
- **Network Monitoring**: Network interface monitoring with traffic stats
- **Battery Status**: Battery level and charging status
- **Keyboard Layout**: Real-time keyboard layout indicator
- **NVIDIA GPU**: GPU temperature and usage monitoring
- **Clock**: Custom time display with calendar integration
- **Custom Icons**: Material Design and Typicons support

## Modules

- `batt` - Battery status and charging indicator
- `ccusage` - CPU usage monitoring
- `dsk` - Disk space monitoring
- `kbdlayout` - Keyboard layout switching detection
- `load` - System load average
- `ltime` - Time and date display
- `mem` - Memory usage monitoring
- `netm` - Network interface monitoring
- `nvidia` - NVIDIA GPU monitoring
- `temp` - Temperature sensors monitoring

## Installation

### Prerequisites

- Go 1.18 or later
- i3 window manager
- X11 environment

### Install

```bash
go install github.com/AnatolyShirykalov/custom_barista@latest
```

### Font Setup

Copy the included fonts to your fonts directory:

```bash
cp -r fonts/* ~/.fonts/
fc-cache -fv
```

## Configuration

### i3 Configuration

Add to your `~/.i3/config` or `~/.config/i3/config`:

```
bar {
    position top
    status_command exec $GOPATH/bin/custom_barista
    font pango:PragmataPro Mono 11
    colors {
        background #2f2f2f
        statusline #ffffff
        separator #666666
    }
}
```

### Color Scheme

The bar uses a custom color scheme:
- `good`: #6d6 (green) - Normal/good status
- `degraded`: #dd6 (yellow) - Warning status  
- `bad`: #d66 (red) - Critical status
- `dim-icon`: #777 (gray) - Inactive icons

## Building from Source

```bash
git clone https://github.com/AnatolyShirykalov/custom_barista.git
cd custom_barista
go build -o custom_barista
```

## Dependencies

- [barista.run](https://barista.run) - Core status bar framework
- [xgb](https://github.com/BurntSushi/xgb) - X11 protocol bindings
- [xgbutil](https://github.com/BurntSushi/xgbutil) - X11 utilities

## License

Apache 2.0 License (see LICENSE file)
