# detect-version.ps1
# 从 Electron crash dump 文件中自动检测 Electron 版本
# 用法: .\scripts\detect-version.ps1 <path-to-dump-file>
# 输出版本号到 stdout（如 "39.4.0"），可被其它脚本捕获使用:
#   $ver = .\scripts\detect-version.ps1 .\dumps\crash.dmp
#   .\scripts\analyze.ps1 .\dumps\crash.dmp -ElectronVersion $ver
#
# 说明: 进度信息输出到 stderr（Write-Warning），纯版本号输出到 stdout（可被捕获）

param(
    [Parameter(Mandatory=$true)]
    [string]$DumpPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DumpPath)) {
    Write-Warning "ERROR: 找不到文件: $DumpPath"
    exit 1
}

$DumpFile = Get-Item $DumpPath
Write-Warning "检测 dump: $($DumpFile.Name)"

$dumpBytes = [System.IO.File]::ReadAllBytes($DumpFile.FullName)
$dumpText = [System.Text.Encoding]::ASCII.GetString($dumpBytes)

$ElectronVersion = ""

# 方法 1: 从 Crashpad annotation 中匹配
# Electron 会在 minidump 的 annotation 流中写入 "Electron" 键，值为 "ver" + 版本号
# 格式: <key_len><key><value_name_len><value_name><value_len><value>
# 例如: 08 00 00 00 "Electron" 03 00 00 00 "ver" 06 00 00 00 "39.4.0"
if ($dumpText -match 'Electron[\x00-\x1F]+ver[\x00-\x1F]+(\d+\.\d+\.\d+)') {
    $ElectronVersion = $matches[1]
    Write-Warning "  从 Crashpad annotation 检测到: v$ElectronVersion"
} else {
    # 方法 2: 搜索 dump 中的语义化版本号，过滤 Electron 典型版本范围
    $allVersions = [regex]::Matches($dumpText, '(?<!\w)(\d{1,2}\.\d{1,2}\.\d{1,4})(?!\w)') |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique

    # Electron 主版本号通常 >= 10
    $candidates = @()
    foreach ($v in $allVersions) {
        $major = ($v -split '\.')[0]
        if ([int]$major -ge 10) {
            $candidates += $v
        }
    }

    if ($candidates.Count -eq 1) {
        $ElectronVersion = $candidates[0]
        Write-Warning "  从 dump 字符串推断: v$ElectronVersion"
    } elseif ($candidates.Count -gt 1) {
        Write-Warning "  检测到多个候选版本: $($candidates -join ', ')"
        Write-Warning "  请手动指定 -ElectronVersion"
    } else {
        Write-Warning "  未能检测到 Electron 版本"
    }
}

# 纯版本号输出到 stdout 供脚本捕获
if ($ElectronVersion) {
    Write-Output $ElectronVersion
} else {
    exit 1
}
