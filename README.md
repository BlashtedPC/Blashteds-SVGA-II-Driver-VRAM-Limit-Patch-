<p align="center">
  <img src="https://github.com/BlashtedPC/Blashteds-SVGA-II-Driver-VRAM-Limit-Patch-/raw/refs/heads/main/windows-2000-2y-1366x768.png" alt="Windows 2000 VMware SVGA II" width="900">
</p>

# VMware SVGA II Driver VRAM Limit Patch## Patching `vmx_svga.sys`

This patch removes a hard-coded 64 MiB VRAM limit in the VMware SVGA II driver used by VMware Tools 10.0.12.

The patcher modifies the user's own copy of `vmx_svga.sys`. The original VMware driver is not included with this project.

### Requirements

* A modern Windows PC with PowerShell
* Your own copy of `vmx_svga.sys` from VMware Tools 10.0.12
* `patch-vmx-svga.ps1` from this repository
* A Windows 2000 VM using the VMware SVGA II driver

---

## 1. Get your original `vmx_svga.sys`

Obtain `vmx_svga.sys` from your own legitimate VMware Tools 10.0.12 installation/package.

**Do not use a driver from a different VMware Tools version unless you have verified that it is the same binary analyzed by this project.**

Create a folder on your modern Windows PC containing:

```text
C:\VMwareSVGA-Patch\
    patch-vmx-svga.ps1
    vmx_svga.sys
```

The exact location does not matter.

---

## 2. Open PowerShell in the patch folder

In File Explorer, open the folder containing `patch-vmx-svga.ps1` and `vmx_svga.sys`.

Click the address bar, type:

```powershell
powershell
```

and press Enter.

Verify that both files are present:

```powershell
Get-ChildItem
```

You should see:

```text
patch-vmx-svga.ps1
vmx_svga.sys
```

---

## 3. Before running the patcher

**Only use this patcher with the VMware SVGA II `vmx_svga.sys` binary analyzed by this project.**

The patcher checks the expected file size and the original bytes at the patch location before making any changes.

If the patcher reports an unexpected file size or does not find:

```text
76 03
```

at file offset:

```text
0x13FCA
```

**stop and do not force the patch.**

A different VMware Tools release may use different code and different offsets.

---

## 4. Run the patcher

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\patch-vmx-svga.ps1 .\vmx_svga.sys
```

The patcher will verify that the input file has the expected characteristics before modifying it.

If everything matches, it will create:

```text
vmx_svga_patched.sys
```

You should see something similar to:

```text
Patch successful!

Changed:
  0x13FCA: 76 03 -> EB 03

PE checksum: 0x0001E7F1

Output:
  vmx_svga_patched.sys
```

---

## 5. Verify the patched file

You can independently verify the patched bytes with PowerShell:

```powershell
$bytes = [System.IO.File]::ReadAllBytes(".\vmx_svga_patched.sys")

"{0:X2} {1:X2}" -f $bytes[0x13FCA], $bytes[0x13FCB]
```

The result should be:

```text
EB 03
```

You can also verify the original file:

```powershell
$bytes = [System.IO.File]::ReadAllBytes(".\vmx_svga.sys")

"{0:X2} {1:X2}" -f $bytes[0x13FCA], $bytes[0x13FCB]
```

The result should be:

```text
76 03
```

If the original file does not contain `76 03` at this location, **do not attempt to patch it.**

---

## 6. Verify the SHA-256 hashes

The following hashes identify the exact driver versions analyzed by this project.

### Original

```text
42E3C0ABC99AD5E4F6E39B1C6CCC4D66C3A611750B29C10F96F04E52CF393962
```

Verify your original file with:

```powershell
Get-FileHash ".\vmx_svga.sys" -Algorithm SHA256
```

### Patched

```text
98EA4BBB102C5B6D20A3A06CE6B3DA67141600BEBE102932ADE3DE466B8EAAB8
```

Verify the patched file with:

```powershell
Get-FileHash ".\vmx_svga_patched.sys" -Algorithm SHA256
```

The hash should match the corresponding value above.

---

## 7. What the patch changes

The patch changes exactly two code bytes in the driver.

Original:

```text
File offset 0x13FCA:

76 03
```

Patched:

```text
EB 03
```

In x86 assembly, this changes:

```asm
JBE +3
```

to:

```asm
JMP +3
```

The original instruction allows execution to continue into the instruction that enforces the 64 MiB limit when the VRAM value is above the limit.

That following instruction sets the VRAM value to:

```text
0x04000000
```

which is 64 MiB.

The patched unconditional jump skips that overwrite.

The patch therefore allows the VRAM value read from the VMware SVGA device to remain above the driver's 64 MiB limit.

The PE checksum is recalculated after the modification.

---

# Installing the Patched Driver in Windows 2000

The patching process above should be performed on a modern Windows system. The resulting `vmx_svga_patched.sys` then needs to be transferred into the Windows 2000 VM.

## 8. Transfer the patched driver to Windows 2000

Transfer:

```text
vmx_svga_patched.sys
```

into your Windows 2000 VM using whatever method is convenient, such as:

* VMware shared folders
* A Windows network share
* An ISO/CD image
* Virtual removable media
* Another file-transfer method available to your VM

Do not overwrite the existing driver yet.

---

## 9. Back up the original Windows 2000 driver

The existing driver is normally located at:

```text
C:\WINNT\system32\drivers\vmx_svga.sys
```

However, the exact Windows installation directory may differ.

Before replacing it, make a backup:

```cmd
copy C:\WINNT\system32\drivers\vmx_svga.sys C:\WINNT\system32\drivers\vmx_svga.sys.backup
```

If your Windows 2000 installation uses a different Windows directory, adjust the path accordingly.

**Do not delete the backup.**

---

## 10. Replace the driver

Copy the patched driver over the existing driver:

```cmd
copy /Y vmx_svga_patched.sys C:\WINNT\system32\drivers\vmx_svga.sys
```

Adjust the first path if the patched file is located somewhere else.

For example:

```cmd
copy /Y D:\vmx_svga_patched.sys C:\WINNT\system32\drivers\vmx_svga.sys
```

---

## 11. If Windows will not let you replace the file

Windows may have the VMware SVGA II driver in use.

If the file cannot be replaced while Windows is running normally, restart Windows 2000 and select:

**Enable VGA Mode**

Then replace the driver while running in VGA Mode.

You do **not** need to use Safe Mode specifically for this procedure.

After replacing the driver, restart Windows normally.

---

## 12. Check the reported VRAM

After Windows 2000 starts with the patched driver:

1. Right-click the desktop.
2. Select **Properties**.
3. Select the **Settings** tab.
4. Click **Advanced**.
5. Select the **Adapter** tab.
6. Check **Memory Size**.

If VMware is configured to provide 128 MiB of VRAM, the driver should no longer impose its previous 64 MiB software limit.

---

## 13. Restoring the original driver

If you need to revert the change, restore your backup:

```cmd
copy /Y C:\WINNT\system32\drivers\vmx_svga.sys.backup C:\WINNT\system32\drivers\vmx_svga.sys
```

Then restart Windows 2000.

---

# Important

This patch is specifically for the VMware SVGA II driver analyzed by this project.

The patch is **not a universal VMware SVGA patch**.

Different VMware Tools releases may contain different code, offsets, or behavior. Do not blindly apply the `0x13FCA` modification to another driver version.

The patcher intentionally checks the expected file size and bytes before modifying the file. If the expected bytes are not present, it aborts rather than modifying the file.

Always keep a backup of your original driver.

### Technical Summary

```text
Original:
0x13FCA: 76 03    JBE +3

Patched:
0x13FCA: EB 03    JMP +3
```

### File Information

```text
Original SHA-256:
42E3C0ABC99AD5E4F6E39B1C6CCC4D66C3A611750B29C10F96F04E52CF393962

Patched SHA-256:
98EA4BBB102C5B6D20A3A06CE6B3DA67141600BEBE102932ADE3DE466B8EAAB8

Original PE checksum:
0x0001E77C

Patched PE checksum:
0x0001E7F1
```
