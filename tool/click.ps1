param([int]$X, [int]$Y, [string]$Proc = "shuangting")
Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class UI {
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern IntPtr PostMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
  public static IntPtr FindView(IntPtr parent) {
    IntPtr found = IntPtr.Zero;
    EnumChildWindows(parent, (h, l) => {
      var sb = new StringBuilder(64);
      GetClassName(h, sb, 64);
      if (sb.ToString() == "FLUTTERVIEW") { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
  public static void Click(IntPtr h, int x, int y) {
    IntPtr lp = (IntPtr)((y << 16) | (x & 0xFFFF));
    PostMessage(h, 0x0200, IntPtr.Zero, lp);
    PostMessage(h, 0x0201, (IntPtr)1, lp);
    System.Threading.Thread.Sleep(60);
    PostMessage(h, 0x0202, IntPtr.Zero, lp);
  }
}
"@
$p = Get-Process $Proc -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$view = [UI]::FindView($p.MainWindowHandle)
if ($view -eq [IntPtr]::Zero) { Write-Error "FLUTTERVIEW not found"; exit 1 }
[UI]::Click($view, $X, $Y)
Write-Output "click $X,$Y view=$view"
