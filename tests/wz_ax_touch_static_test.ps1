$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $root 'lara/kexploit/wz/WZAXTouch.mm') -Raw
function Require([string]$pattern, [string]$message) {
    if ($source -notmatch $pattern) { throw "FAIL: $message" }
}
# Binary-derived ABI contract: AX128 0x100833308..0x10083331c sets x0..x4.
Require 'Ref \(\*createVirtual\)\(Ref, CFDictionaryRef, const VirtualCallbacksV2 \*, void \*, void \*\)' 'VirtualService create ABI must have five arguments'
Require 'serviceProperties\(\), &callbacks, token, token\)' 'VirtualService properties/generation arguments missing'
Require 'token != generation \|\| service != virtualService' 'Late service notification may activate a replacement host'
Require 'CFNumberGetValue\(\(CFNumberRef\)value, kCFNumberSInt64Type, &result\)' 'Registry ID must be converted from CFNumber'
# 0x1006fa168 dispatches in the remote host after transferring serialized bytes.
Require 'remote_write:remoteBuffer from:source size:' 'Serialized HID bytes are not copied to the remote host'
Require 'call\("CFDataCreate"[\s\S]*call\("IOHIDEventCreateWithData"[\s\S]*call\("IOHIDEventSystemClientCreate"[\s\S]*call\("IOHIDEventSystemClientDispatchEvent"' 'Remote reconstruction/dispatch order changed'
Require 'doRemoteCallStableWithTimeout:5' 'AX remote call timeout argument changed'
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
