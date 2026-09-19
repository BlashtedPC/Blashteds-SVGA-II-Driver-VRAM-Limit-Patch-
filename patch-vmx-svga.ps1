param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [string]$OutputFile = "vmx_svga_patched.sys"
)

function Get-PEChecksum($path) {

    $b = [System.IO.File]::ReadAllBytes($path)

    if ($b.Length -lt 0x40) {
        throw "File is too small to be a PE file."
    }

    # Check MZ signature
    if ($b[0] -ne 0x4D -or $b[1] -ne 0x5A) {
        throw "Input file is not a valid MZ/PE file."
    }

    # Locate PE header
    $pe = [BitConverter]::ToInt32($b, 0x3C)

    if ($pe -lt 0 -or $pe + 0x5C -gt $b.Length) {
        throw "Invalid PE header."
    }

    # Check PE signature
    if ($b[$pe] -ne 0x50 -or
        $b[$pe + 1] -ne 0x45 -or
        $b[$pe + 2] -ne 0x00 -or
        $b[$pe + 3] -ne 0x00) {

        throw "Invalid PE signature."
    }

    # PE Optional Header CheckSum field
    $checksumOffset = $pe + 0x58

    $sum = [uint64]0

    for ($i = 0; $i -lt $b.Length; $i += 2) {

        # Skip existing checksum field
        if ($i -ge $checksumOffset -and
            $i -lt ($checksumOffset + 4)) {
            continue
        }

        if ($i + 1 -lt $b.Length) {
            $word = [uint64]$b[$i] +
                    ([uint64]$b[$i + 1] * 256)
        }
        else {
            $word = [uint64]$b[$i]
        }

        $sum += $word

        $sum = ($sum -band 0xFFFF) +
               ($sum -shr 16)
    }

    $sum = ($sum -band 0xFFFF) +
           ($sum -shr 16)

    $sum = ($sum -band 0xFFFF) +
           ($sum -shr 16)

    $sum += $b.Length

    return [uint32]$sum
}


Write-Host ""
Write-Host "VMware SVGA II Windows 2000 VRAM Patch"
Write-Host "======================================="
Write-Host ""

# Read original
$bytes = [System.IO.File]::ReadAllBytes($InputFile)

# Verify expected size
if ($bytes.Length -ne 102424) {
    throw "Unexpected file size: $($bytes.Length) bytes. Expected 102424 bytes."
}

# Patch location
$offset = 0x13FCA

# Verify original bytes
if ($bytes[$offset] -ne 0x76 -or
    $bytes[$offset + 1] -ne 0x03) {

    $actual = "{0:X2} {1:X2}" -f `
        $bytes[$offset],
        $bytes[$offset + 1]

    throw "Expected 76 03 at file offset 0x13FCA, found $actual. Aborting."
}

Write-Host "Verified original driver."
Write-Host "Found expected bytes: 76 03"
Write-Host ""

# Clone original
$patched = $bytes.Clone()

# Apply 2-byte patch
$patched[$offset]     = 0xEB
$patched[$offset + 1] = 0x03

# Write temporary patched file
[System.IO.File]::WriteAllBytes(
    $OutputFile,
    $patched
)

# Calculate PE checksum
$checksum = Get-PEChecksum $OutputFile

# Reload patched file
$patched = [System.IO.File]::ReadAllBytes($OutputFile)

# Locate PE checksum field
$peOffset = [BitConverter]::ToInt32($patched, 0x3C)
$checksumOffset = $peOffset + 0x58

# Write checksum
$checksumBytes =
    [System.BitConverter]::GetBytes([uint32]$checksum)

for ($i = 0; $i -lt 4; $i++) {
    $patched[$checksumOffset + $i] =
        $checksumBytes[$i]
}

[System.IO.File]::WriteAllBytes(
    $OutputFile,
    $patched
)

Write-Host "Patch successful!"
Write-Host ""
Write-Host "Changed:"
Write-Host "  0x13FCA: 76 03 -> EB 03"
Write-Host ""
Write-Host ("PE checksum: 0x{0:X8}" -f $checksum)
Write-Host ""
Write-Host "Output:"
Write-Host "  $OutputFile"
Write-Host ""