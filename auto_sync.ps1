
$ErrorActionPreference = "Stop"

$Project = "E:\GitHub\my-project"
$LogFile = "$env:LOCALAPPDATA\GitHubAutoSync.log"

function Log($message) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $message"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

try {
    Set-Location $Project

    git rev-parse --is-inside-work-tree | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Not a Git repository"
    }

    # Avoid syncing during a merge or rebase
    $gitDir = (git rev-parse --absolute-git-dir).Trim()
    if ((Test-Path "$gitDir\MERGE_HEAD") -or
        (Test-Path "$gitDir\rebase-merge") -or
        (Test-Path "$gitDir\rebase-apply")) {
        throw "Merge or rebase in progress"
    }

    # Fetch remote updates
    git fetch origin
    if ($LASTEXITCODE -ne 0) {
        throw "Git fetch failed"
    }

    # Stage current changes
    git add -A
    if ($LASTEXITCODE -ne 0) {
        throw "Git add failed"
    }

    git diff --cached --quiet
    $diffCode = $LASTEXITCODE

    if ($diffCode -eq 1) {
        $date = Get-Date -Format "yyyy-MM-dd HH:mm"
        git commit -m "chore: hourly sync $date"
        if ($LASTEXITCODE -ne 0) {
            throw "Git commit failed"
        }
    }
    elseif ($diffCode -ne 0) {
        throw "Git diff failed"
    }

    # Only push when the remote branch is not ahead
    $branch = (git branch --show-current).Trim()
    if (-not $branch) {
        throw "No active branch"
    }

    git rev-parse --verify "refs/remotes/origin/$branch" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Remote branch origin/$branch not found"
    }

    git merge-base --is-ancestor "origin/$branch" HEAD
    if ($LASTEXITCODE -ne 0) {
        throw "Remote has new commits. Pull manually first."
    }

    git push origin $branch
    if ($LASTEXITCODE -ne 0) {
        throw "Git push failed"
    }

    Log "SUCCESS: Repository synced"
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
