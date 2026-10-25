# Captures README screenshots from the Windows debug build using demo data.
# Usage: powershell -File tool/capture_screenshots.ps1   (after `flutter build windows --debug`)
$ErrorActionPreference = 'Stop'
$scale = 1.25   # Windows display scaling; sizes below are logical pixels
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hh, uint flags);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@
[void][W]::SetProcessDPIAware()
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'build\windows\x64\runner\Debug\lumora.exe'
$out = Join-Path $root 'docs\screenshots'
New-Item -ItemType Directory -Force $out | Out-Null
$db = Join-Path $env:TEMP 'lumora-demo.db'
Remove-Item "$db*" -ErrorAction SilentlyContinue

$shots = @(
  @{n='desktop-dashboard'; r='/'; w=1500; h=780},
  @{n='desktop-goals'; r='/goals'; w=1500; h=780},
  @{n='desktop-sessions'; r='/sessions'; w=1500; h=780},
  @{n='desktop-calendar'; r='/calendar'; w=1500; h=780},
  @{n='desktop-analysis'; r='/analysis'; w=1500; h=780},
  @{n='desktop-analytics'; r='/analytics'; w=1500; h=780},
  @{n='desktop-notes'; r='/notes'; w=1500; h=780},
  @{n='desktop-settings'; r='/settings'; w=1500; h=780},
  @{n='mobile-dashboard'; r='/'; w=390; h=780},
  @{n='mobile-goals'; r='/goals'; w=390; h=780},
  @{n='mobile-calendar'; r='/calendar'; w=390; h=780},
  @{n='mobile-insights'; r='/analytics'; w=390; h=780},
  @{n='mobile-more'; r='/more'; w=390; h=780}
)
foreach ($s in $shots) {
  $env:LUMORA_DB = $db; $env:LUMORA_SEED_DEMO = '1'; $env:LUMORA_ROUTE = $s.r
  $env:LUMORA_WINDOW = "$($s.w)x$($s.h)"
  $p = Start-Process $exe -PassThru
  Start-Sleep -Seconds 7
  $p.Refresh()
  $h = $p.MainWindowHandle
  [void][W]::MoveWindow($h, 0, 0, [int]($s.w * $scale) + 16, [int]($s.h * $scale) + 39, $true)
  [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(1900, 1000)
  [void][W]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x0043)   # topmost, no move/resize, show
  [void][W]::SetForegroundWindow($h)
  Start-Sleep -Seconds 2
  $r = New-Object W+RECT
  [void][W]::GetWindowRect($h, [ref]$r)
  # Inset 8px: Windows adds an invisible resize border that would show what is behind the window.
  $bw = ($r.R - $r.L) - 16; $bh = ($r.B - $r.T) - 8
  $bmp = New-Object System.Drawing.Bitmap $bw, $bh
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.L + 8, $r.T, 0, 0, $bmp.Size)
  $bmp.Save((Join-Path $out "$($s.n).png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Stop-Process -Id $p.Id -Force
  Start-Sleep -Seconds 1
  Write-Host "captured $($s.n)"
}
