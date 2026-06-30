$token = $env:GITHUB_TOKEN
if (-not $token) {
    Write-Error "GITHUB_TOKEN environment variable not set"
    exit 1
}
$headers = @{
    Authorization = "token $token"
    'Content-Type' = 'application/json'
}
$body = '{"name":"ResearchPaper","description":"The Cognitive Architecture of the Untamed Mind","private":false}'
try {
    $response = Invoke-WebRequest -Uri 'https://api.github.com/user/repos' -Method POST -Headers $headers -Body $body -UseBasicParsing
    Write-Output $response.Content
} catch {
    Write-Output $_.Exception.Response.StatusCode.value__
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    Write-Output $reader.ReadToEnd()
}
