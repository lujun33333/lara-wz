$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $root 'lara/kexploit/wz/WZAXTouch.mm') -Raw -Encoding UTF8
function Require([string]$pattern, [string]$message) {
    if ($source -notmatch $pattern) { throw "FAIL: $message" }
}
# Binary-derived ABI contract: AX128 0x100833308..0x10083331c sets x0..x4.
Require 'Ref \(\*createVirtual\)\(Ref, CFDictionaryRef, const VirtualCallbacksV2 \*, void \*, void \*\)' 'VirtualService create ABI must have five arguments'
Require 'serviceProperties\(\), &callbacks, token, token\)' 'VirtualService properties/generation arguments missing'
Require 'token != generation \|\| service != virtualService' 'Late service notification may activate a replacement host'
Require 'CFNumberGetValue\(\(CFNumberRef\)value, kCFNumberSInt64Type, &result\)' 'Registry ID must be converted from CFNumber'
# 0x1006fa168 dispatches locally: AX Pro v1.2.8 builds the HID event in-process
# and hands it to its own IOHIDEventSystemClientDispatchEvent. There is no
# serialized transfer, no remote reconstruction, and no RemoteCall host.
Require 'AX_HID\(dispatchEvent, "IOHIDEventSystemClientDispatchEvent"\)' 'Local IOHID dispatch symbol is not resolved'
Require 'bool dispatchLocal\(Ref event\)[\s\S]{0,220}api\.dispatchEvent\(localClient, event\)' 'Local dispatch does not use our own system client'
Require 'const bool result = dispatchLocal\(parent\)' 'Parent event is not dispatched locally'
Require 'attribute\(parent, 0xb0007, values.parentMask\)' 'Parent phase mask is absent'
Require 'attribute\(parent, 0xb0016, 1\)' 'Parent integrated-display attribute is absent'
Require 'api\.append\(parent, finger, 1\)' 'AX parent append options changed'
Require 'oldVirtual\) \{ api\.removeVirtual\(oldVirtual\); CFRelease\(oldVirtual\); \}' 'Virtual service cleanup order changed'
Require 'oldClient\) \{ api\.cancel\(oldClient\); CFRelease\(oldClient\); \}' 'System client cleanup order changed'
Require 'tapPending\.compare_exchange_strong' 'Tap submission must not wait synchronously behind remote dispatch'
Require 'if \(NSThread\.isMainThread\) readSurface\(\);[\s\S]{0,120}dispatch_sync\(dispatch_get_main_queue\(\), readSurface\)' 'UIScreen surface metrics are read off the main thread'
Require 'if \(NSThread\.isMainThread\) convert\(\);[\s\S]{0,120}dispatch_sync\(dispatch_get_main_queue\(\), convert\)' 'UIKit coordinate conversion is performed off the main thread'
if ($source -match 'api\.remoteDispatch\s*\(') { throw 'FAIL: Remote dispatch called in local process' }
'PASS: AX128 SimTouch ABI, remote dispatch, lifecycle and nonblocking submission contracts'
