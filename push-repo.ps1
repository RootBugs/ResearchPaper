$env:GIT_REDIRECT_STDERR = '2>&1'
$token = $env:GITHUB_TOKEN
if (-not $token) {
    Write-Error "GITHUB_TOKEN environment variable not set"
    exit 1
}
cd $PSScriptRoot
git push "https://RootBugs:${token}@github.com/RootBugs/ResearchPaper.git" master -f
