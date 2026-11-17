# Upstream issue draft: nvidia_gpu shows 0° with newer nvidia-smi

Target: https://github.com/greshake/i3status-rust/issues/new

Search done 2026-11-17 (GitHub search API, repo greshake/i3status-rust, "nvidia_gpu temperature", "nvidia-smi float"):
no open or closed issue about a float `temperature.gpu`. Related but different: #1769 (`[N/A]` fields, fixed in e473555
by mapping them to 0 via `unwrap_or_default()`, which is also what hides this bug).

## Title

nvidia_gpu: temperature always shows 0° when nvidia-smi prints a float (`temperature.gpu`)

## Environment

- i3status-rust 0.40.1 (Arch Linux package)
- nvidia-smi 620.70.06, NVML 620.70 (`nvidia-smi --version`)
- GPU: NVIDIA GeForce RTX 5070 Ti

## Steps to reproduce

1. Use a driver whose `nvidia-smi` prints `temperature.gpu` as a decimal number.
2. Configure the block with defaults:
   ```toml
   [[block]]
   block = "nvidia_gpu"
   ```
3. Look at the block: the temperature part reads `0°` (and the state is always idle), while utilization and memory are correct.

## What the block runs

From `src/blocks/nvidia_gpu.rs` (v0.40.1, `QUERY`/`FORMAT` consts and the spawn in `run`):

```
nvidia-smi -l 1 -i 0 --query-gpu=name,memory.total,utilization.gpu,memory.used,temperature.gpu,fan.speed,clocks.current.graphics,power.draw, --format=csv,noheader,nounits
```

Raw output on this machine (same query without `-l`):

```
NVIDIA GeForce RTX 5070 Ti, 16303, 81, 5433, 44.79, 32, 2880, 147.67
```

Fifth field (`temperature.gpu`) is `44.79`, a float.

## Expected

Temperature shows about `45°` and the idle/good/info/warning state follows it.

## Actual

`0°`. No error is shown.

## Suspected cause

The field is declared `u32`:
https://github.com/greshake/i3status-rust/blob/v0.40.1/src/blocks/nvidia_gpu.rs#L210
and parsed with `parse::<u32>().unwrap_or_default()` via the `parse!` macro, so `"44.79"` fails to parse and silently becomes 0:
https://github.com/greshake/i3status-rust/blob/v0.40.1/src/blocks/nvidia_gpu.rs#L258
(same on master at the time of writing). `fan_speed: u32` uses the same path and would break the same way if a driver ever prints a decimal there.

## Suggested fix

Declare `temperature: f64`, parse with `f64` in the `parse!` call, and round where it is used: the state match (`info.temperature` compared against idle/good/info/warning) can compare the f64 directly, and `Value::degrees_c(info.temperature)` takes a float already (the block's other fields such as `utilization` are f64). If an integer display is preferred, use `.round()`.
