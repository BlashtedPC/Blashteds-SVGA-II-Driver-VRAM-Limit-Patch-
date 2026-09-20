After hours of deliberate tinkering with Ghidra on multiple different patch drafts, various PowerShell commands, failing checksums and the great help of AI for reverse engineering, I was able to successfully patch the problematic VMware SVGA II "vmx_svga.sys" driver with a two-byte patch to correctly reflect the higher VRAM in the OS now, specifically the driver's architectural maximum of 128MB.

This was a deliberate effort to help further the preservation of retro PC gaming. One of the big problems that we will one day face with retro gaming is that retro PC parts are becoming less and less available by the year and top notch parts from the era are not cheap for their relative age. Things break down, capacitors/power supplies blow, old hard drives go kaput. One day there will no longer be an affordable or viable option for building a retro gaming PC. While online storefronts like GOG offer their own preservation programs to bring old games back from the dead with modern OS compatibility fixes, the releases are drops in a swimming pool compared to all of the games lost to time from this era. Many games will never see a release on GOG nor will they ever get a proper port from major companies. Many are PC exclusive and never saw console release. It is important that just like video game console emulation projects (like Dolphin, PCSX2, RPCS3, etc.), we do everything we can to also preserve PC gaming from a lost era that should not only be accessible to everyone, but also support a complete library of old games that are not only preserved, but are also able to be played in an environment offering solid game performance on your own local machine in the easiest way possible. 

Cheers everybody! 🍻

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

(Games can now confidently utilize the higher VRAM available to them as advertised and Windows 2000 will now display the correct information appropriately. No more guesswork if the higher VRAM is actually being used by games or if such information is relayed to the program. We can be confident that the higher VRAM shown is available and ready to use. For example, CivCity Rome (2006) recommends 128MB for maximum settings, and it runs smoothly at 1600x1200@60Hz Highest Settings via the patched driver. Additonally, 3DMark2001SE reports scores well over 23,000 for a 1600x1200 Highest Settings Benchmark Test. This driver patch is a nice fix because mid-2000s games started advocating or even requiring 128MB VRAM as technology advanced. This fix enables Windows 2000 VMware VMs to properly play the later years of that OS' gaming cycle with appropriate resources without forcing you over to XP which has it's own issues.)

Original Discussion Thread: https://community.broadcom.com/vmware-cloud-foundation/discussion/workstation-pro-26h1-set-to-128mb-vram-but-windows-2000-vm-not-reporting-it?ReplyInline=c5bfd581-5335-4df9-9f50-7e0a2568f1d6

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

AI Summary that breaks down what I did and what the root cause was:  

I spent some time reverse-engineering the Windows 2000 vmx_svga.sys driver in Ghidra because my VM was configured with 128 MB VRAM, but Windows 2000 was only reporting 64 MB. 

The issue turned out to be a hard-coded 64 MiB cap in the SVGA II driver.

The driver reads the VRAM size from the VMware SVGA registers and, for SVGA IDs 400 and 500, contains this logic:

CMP  dword ptr [ESI+10], 04000000h
JBE  ...
MOV  dword ptr [ESI+10], 04000000h

0x04000000 = 64 MiB.

In other words, if the driver detected more than 64 MiB of VRAM, it explicitly replaced the detected value with 64 MiB.

I patched the preceding conditional jump:

Original:
76 03    JBE

Patched:
EB 03    JMP

This is a 2-byte code patch. It causes the driver to skip the instruction that writes the 64 MiB value, allowing the original VRAM value to remain intact.

I verified the patched file against a clean copy with fc /b. The only actual code change was:

00013FCA: 76 EB

The PE checksum also had to be recalculated. The original checksum was 0x0001E77C, and the correctly recalculated checksum for the patched driver was 0x0001E7F1.

After installing the patched driver in Windows 2000, the VMware SVGA II driver loaded successfully, confirming that the patch works.

So the short version:

VMware was providing 128 MB, but the Windows 2000 SVGA II driver was deliberately clamping the reported VRAM to 64 MiB for SVGA IDs 400/500. A 2-byte patch removes that cap.

This appeared to be a driver-side limitation rather than a limitation of the VMware virtual hardware itself.
