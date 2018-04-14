function test($name, $appFx, $appFxVer, $appTfm, $adddFx, $adddFxVer, $storeTFM, $hsVer)
{
    if (!$hsVer)
    {
        $hsVer = $adddFxVer;
    }

    $dirName = Join-Path -Path $PSScriptRoot -ChildPath "test-$name";
    Write-Host "Testing $dirname" -ForegroundColor Green;

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
    $storeLibDir = "$storeDir\x64\$storeTFM\hs\$hsVer\";
    mkdir $storeDir | Out-Null;
    dotnet publish src\hs\hs.csproj -o $storeLibDir -p:Version=$hsVer > "$dirName\publish.hs.log";

    $adddDir = Join-Path -Path $dirName -ChildPath "addd";
    $adddLibDir = "$adddDir\shared\$adddFx\$adddFxVer";
    mkdir $adddLibDir | Out-Null;
    Copy-Item "$storeLibDir\hs.deps.json" $adddLibDir;

    $runFile = "$dirName\run.ps1";

    "`$env:DOTNET_ADDITIONAL_DEPS = `"$adddDir`";" | Out-File $runFile -Append
    "`$env:DOTNET_SHARED_STORE = `"$storeDir`";" | Out-File $runFile -Append
    "`$env:PATH = `"$dirName\..\dotnet\`";" | Out-File $runFile -Append
    "dotnet `"$appDir\app.dll`"" | Out-File $runFile -Append

    powershell.exe -File $runFile;
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

dotnet build src\hs\hs.csproj > Out-Null;
dotnet build src\app\app.csproj > Out-Null;

Write-Host "Lets go!" -ForegroundColor Yellow;

test -name "2.0.0" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "2.0.0" -appTfm "netcoreapp2.0" `
     -adddFx "Microsoft.NetCore.App" `
     -adddFxVer "2.0.0" `
     -storeTFM "netcoreapp2.0";

test -name "2.0.7_app_2.0.0_deps" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "2.0.7" `
     -appTfm "netcoreapp2.0" `
     -adddFx "Microsoft.NetCore.App" `
     -adddFxVer "2.0.0" `
     -storeTFM "netcoreapp2.0";

test -name "2.0.7_app_2.0.1_deps" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "2.0.7" `
     -appTfm "netcoreapp2.0" `
     -adddFx "Microsoft.NetCore.App" `
     -adddFxVer "2.0.1" `
     -storeTFM "netcoreapp2.0";

$currentMNCA = "2.1.0-preview2-26406-04";

test -name "$currentMNCA-app_2.0.0_deps" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "$currentMNCA" `
     -appTfm "netcoreapp2.0" `
     -adddFx "Microsoft.NetCore.App" `
     -adddFxVer "2.0.0" `
     -storeTFM "netcoreapp2.0";

test -name "$currentMNCA-app_2.1.0-preview1_deps" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "$currentMNCA" `
     -appTfm "netcoreapp2.0" `
     -adddFx "Microsoft.NetCore.App" `
     -adddFxVer "2.1.0-preview1" `
     -storeTFM "netcoreapp2.0";

$currentANCA = "2.1.0-preview2-final"

test -name "$currentANCA-app_2.0.0_deps" `
     -appFx "Microsoft.AspNetCore.App" `
     -appFxVer "$currentANCA" `
     -appTfm "netcoreapp2.0" `
     -adddFx "Microsoft.NetCore.App" `
     -adddFxVer "2.0.0" `
     -storeTFM "netcoreapp2.0";
