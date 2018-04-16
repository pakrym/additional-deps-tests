function assert($text)
{
    if (!($log -like "*$text*"))
    {
        Write-Error "Output $log didn't contain $text"
    }
}

function hs($adddFx, $adddFxVer, $storeTFM, $hsName, $hsVer)
{
    Write-Host "   HostringStartup $adddFx $adddFxVer $storeTFM" -ForegroundColor Green;

    if (!$hsName)
    {
        $hsName = "hs";
    }
    if (!$hsVer)
    {
        $hsVer = $adddFxVer;
    }

    $hsList.Add($hsName);

    $storeLibDir = "$storeDir\x64\$storeTFM\hs\$hsVer\";
    dotnet publish src\hs\hs.csproj -o $storeLibDir -p:Version=$hsVer > "$dirName\publish.hs.log";

    $adddLibDir = "$adddDir\shared\$adddFx\$adddFxVer";
    mkdir $adddLibDir | Out-Null;
    Copy-Item "$storeLibDir\hs.deps.json" $adddLibDir;
}

function test($name, $appFx, $appFxVer, $appTfm, $hs, $verify)
{
    $dirName = Join-Path -Path $PSScriptRoot -ChildPath "test-$name";
    Write-Host "Testing $appTfm $appFx $appFxVer" -ForegroundColor Green;

    mkdir $dirName | Out-Null;

    $appDir = Join-Path -Path $dirName -ChildPath "app";
    dotnet publish src\app\app.csproj -f $appTfm -o $appDir > "$dirName\publish.app.log";

    $runtimeConfigFile = Join-Path -Path $appDir -ChildPath "app.runtimeconfig.json";
    $runtimeConfig = (Get-Content $runtimeConfigFile -Raw) | ConvertFrom-Json;
    $runtimeConfig.runtimeOptions.tfm = $appTfm;
    $runtimeConfig.runtimeOptions.framework.name = $appFx;
    $runtimeConfig.runtimeOptions.framework.version = $appFxVer;
    $runtimeConfig | ConvertTo-Json | set-content $runtimeConfigFile

    $storeDir = Join-Path -Path $dirName -ChildPath "store\";
    $adddDir = Join-Path -Path $dirName -ChildPath "addd";

    mkdir $storeDir | Out-Null;
    mkdir $adddDir | Out-Null;

    $hsList = New-Object System.Collections.Generic.List[System.String]
    & $hs;
    $hsList = ($hsList | sort-object -Unique) -join ' ';

    $runFile = "$dirName\run.ps1";

    "`$env:DOTNET_ADDITIONAL_DEPS = `"$adddDir`";" | Out-File $runFile -Append
    "`$env:DOTNET_SHARED_STORE = `"$storeDir`";" | Out-File $runFile -Append
    "`$env:PATH = `"$dirName\..\dotnet\`";" | Out-File $runFile -Append
    "dotnet `"$appDir\app.dll`" $hsList " | Out-File $runFile -Append

    $log = & powershell.exe -File $runFile;
    $log = $log.Replace($dirName, "TESTROOT");
    $log = $log.Replace($PSScriptRoot, "ROOT");
    $log | Write-Host;

    & $verify;
}

$ErrorActionPreference = "Stop"

if (!$env:PATH.EndsWith("d:\temp\adddepsver\"))
{
    $env:PATH = "d:\temp\adddepsver\;$env:PATH";
}

if (Test-Path "$env:ProgramFiles\dotnet")
{
    Write-Error "$env:ProgramFiles\dotnet should not exist";
    exit;
}

Write-Host "Getting things ready..." -ForegroundColor Yellow;

rm test-* -Recurse -Force

dotnet build src\hs\hs.csproj | Out-Null;
dotnet build src\app\app.csproj | Out-Null;

Write-Host "Lets go!" -ForegroundColor Yellow;

test -name "2.0.0" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "2.0.0" `
     -appTfm "netcoreapp2.0" `
     { hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.0.0" -storeTFM "netcoreapp2.0"; } `
     { assert "TESTROOT\store\x64\netcoreapp2.0\hs\2.0.0\hs.dll"; }

test -name "2.0.7_app_2.0.0_deps" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "2.0.7" `
     -appTfm "netcoreapp2.0" `
     {
        hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.0.0" -storeTFM "netcoreapp2.0";
        hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.0.1" -storeTFM "netcoreapp2.0";
    }`
    { assert "TESTROOT\store\x64\netcoreapp2.0\hs\2.0.1\hs.dll"; }

test -name "2.0.7_app_2.0.1_deps" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "2.0.7" `
     -appTfm "netcoreapp2.0" `
     { hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.0.1" -storeTFM "netcoreapp2.0"; }`
     { assert "TESTROOT\store\x64\netcoreapp2.0\hs\2.0.1\hs.dll"; }

$currentMNCA = "2.1.0-preview2-26406-04";

# storeTFM should be 2.0 or any
test -name "$currentMNCA-app_2.0.0_deps" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "$currentMNCA" `
     -appTfm "netcoreapp2.1" `
     { hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.0.0" -storeTFM "netcoreapp2.1"; } `
     {
        assert "ROOT\dotnet\shared\Microsoft.NetCore.App\$currentMNCA\Microsoft.NetCore.App.deps.json";
        assert "TESTROOT\store\x64\netcoreapp2.1\hs\2.0.0\hs.dll";
     }

test -name "$currentMNCA-app_2.1.0-preview1_deps" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "$currentMNCA" `
     -appTfm "netcoreapp2.1" `
     {
        hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.0.0" -storeTFM "netcoreapp2.0";
        hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0-preview1" -storeTFM "netcoreapp2.1";
     }`
     {
         assert "ROOT\dotnet\shared\Microsoft.NetCore.App\$currentMNCA\Microsoft.NetCore.App.deps.json";
         assert "TESTROOT\store\x64\netcoreapp2.1\hs\2.1.0-preview1\hs.dll";
     }

$currentANCA = "2.1.0-preview2-final"

test -name "$currentANCA-app_2.0.0_deps" `
     -appFx "Microsoft.AspNetCore.App" `
     -appFxVer "$currentANCA" `
     -appTfm "netcoreapp2.0" `
     { hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.0.0" -storeTFM "netcoreapp2.0"; }`
     {
        assert "ROOT\dotnet\shared\Microsoft.AspNetCore.App\$currentANCA\Microsoft.AspNetCore.App.deps.json"
        assert "TESTROOT\store\x64\netcoreapp2.0\hs\2.0.0\hs.dll";
     }
