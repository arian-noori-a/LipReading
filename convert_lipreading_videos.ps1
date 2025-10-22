# convert_lipreading_videos.ps1
# Converts videos under .\<numeric label>\ to MP4 (H.264 + AAC)

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
  Write-Error "ffmpeg not found. Install with: winget install Gyan.FFmpeg"
  exit 1
}

$root = (Get-Location).Path
Write-Host "Repo root:" $root

# Only pick files inside folders whose name is all digits (labels)
$videos = Get-ChildItem -Recurse -File | Where-Object {
  $_.Directory.Name -match '^\d+$' -and $_.Extension -match '^\.(mp4|mov|mkv|webm|avi)$'
}

if (-not $videos -or $videos.Count -eq 0) {
  Write-Host "No videos found under .\<number>\*. (Checked: mp4, mov, mkv, webm, avi)"
  exit 0
}

$total = $videos.Count
$converted = 0
Write-Host "Found $total video(s). Converting to H.264 + AAC (MP4)...`n"

$i = 0
foreach ($file in $videos) {
  $i++
  $inPath  = $file.FullName
  $base    = Join-Path $file.DirectoryName $file.BaseName
  $outPath = "$base.mp4"
  $tmpOut  = "$base.h264aac.tmp.mp4"

  Write-Host "[$i/$total] Converting: $($inPath.Replace($root, '.'))"

  $ffArgs = @(
    "-y",
    "-hide_banner", "-loglevel", "error", "-stats",
    "-i", $inPath,
    "-map", "0:v:0", "-map", "0:a?",
    "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
    "-c:a", "aac", "-b:a", "192k", "-ac", "2", "-ar", "48000",
    "-movflags", "+faststart",
    $tmpOut
  )

  $proc = Start-Process -FilePath "ffmpeg" -ArgumentList $ffArgs -NoNewWindow -PassThru -Wait
  if ($proc.ExitCode -ne 0 -or -not (Test-Path $tmpOut)) {
    Write-Warning "ffmpeg failed on: $inPath"
    continue
  }

  try {
    Move-Item -Force $tmpOut $outPath
    if ($file.Extension -ne ".mp4") { Remove-Item -Force $inPath }
    $converted++
  } catch {
    Write-Warning "Failed to move/replace output for: $inPath ; $_"
  }
}

Write-Host "`nDone. Converted $converted / $total video(s) to MP4 (H.264 + AAC)."
Write-Host "Tip: For smaller files, increase -crf (e.g., 22)."
