$ErrorActionPreference = "Stop"
$newPath = @()
$env:Path.split(';') | ForEach-Object {
    if(-not (Test-Path (Join-Path $_ 'winpty-agent.exe'))){
        $newPath += $_
    }
}
$backupPath = $env:Path
$env:Path = ($newPath -join ';')
try{
    Get-Command 'winpty-agent'
    $stillExists = $True
}catch{
    $stillExists = $False
}
if($stillExists){ throw }
Get-ChildItem C:\Python* | ForEach-Object{
    $python = $_.Name
    Write-Host ('Testing ' + $python) -ForegroundColor Magenta
    $originPath = $env:Path
    $env:Path = 'C:\' + $python + '\Scripts;' + 'C:\' + $python + ';' + $env:Path
    Write-Host (python -c "print(__import__('sys').version)") -ForegroundColor Yellow

    if(Test-Path build){ Remove-Item -Recurse build }
    if(Test-Path dist){ Remove-Item -Recurse dist }

    if($python.StartsWith('Python35') -or $python.StartsWith('Python36')){
        python .appveyor.py
        if(-not $?){ throw }
        Write-Host ('Success ' + $python) -ForegroundColor Green
    }else{
        Write-Host ('Skip ' + $python) -ForegroundColor Gray
    }

    $env:Path = $originPath
}
$env:Path = $backupPath
