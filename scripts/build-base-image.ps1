param(
    [string]$Tag = "asuracodes/mcu-lab:base"
)

Write-Host "Building base image as $Tag (this may take a long time)..."
docker build --progress=plain -f .devcontainer/Dockerfile -t $Tag ..
$last = $LASTEXITCODE
if ($last -eq 0) {
    Write-Host "Build succeeded. Reopen workspace in container — it will use image $Tag."
}
else {
    Write-Error "Build failed with exit code $last."
    exit $last
}
