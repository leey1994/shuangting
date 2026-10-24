param([int]$X = 600, [int]$Y = 600, [int]$Notches = 5, [string]$Proc = "shuangting")
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class S {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, int d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  public struct POINT { public int X, Y; }
  public static void Wheel(IntPtr h, int x, int y, int n) {
    SetForegroundWindow(h);
    var p = new POINT { X = x, Y = y };
    ClientToScreen(h, ref p);
    SetCursorPos(p.X, p.Y);
    System.Threading.Thread.Sleep(120);
    mouse_event(0x0800, 0, 0, -120 * n, IntPtr.Zero);
  }
}
"@
$p = Get-Process $Proc -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
[S]::Wheel($p.MainWindowHandle, $X, $Y, $Notches)
Write-Output "wheel $Notches at $X,$Y"
