function test($name, $appFx, $appFxVer, $appTfm, $adddFx, $adddFxVer, $storeTFM)
{
    $dirName = Join-Path -Path $PSScriptRoot -ChildPath "test-$name";
    if (Test-Path $dirName)
    {
        Write-Host "Removing $dirname";
        Remove-Item $dirName -Recurse -Force;
    }

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
    $storeLibDir = "$storeDir\x64\$storeTFM\hs\1.0.0\";
    mkdir $storeDir | Out-Null;
    dotnet publish src\hs\hs.csproj -o $storeLibDir > "$dirName\publish.hs.log";

    $adddDir = Join-Path -Path $dirName -ChildPath "addd";
    $adddLibDir = "$adddDir\shared\$adddFx\$adddFxVer";
    mkdir $adddLibDir | Out-Null;
    Copy-Item "$storeLibDir\hs.deps.json" $adddLibDir;

    $runFile = "$dirName\run.ps1";

    "`$env:DOTNET_ADDITIONAL_DEPS = `"$adddDir`";" | Out-File $runFile -Append
    "`$env:DOTNET_SHARED_STORE = `"$storeDir`";" | Out-File $runFile -Append
    "$dirName\..\dotnet\dotnet `"$appDir\app.dll`"" | Out-File $runFile -Append

    & $runFile;
}

$ErrorActionPreference = "Stop"

if (!$env:PATH.EndsWith("d:\temp\adddepsver\"))
{
    $env:PATH = "d:\temp\adddepsver\;$env:PATH";
}

dotnet build src\hs\hs.csproj
dotnet build src\app\app.csproj

test -name "2_0_all" -appFx "Microsoft.NetCore.App" -appFxVer "2.0.0" -appTfm "netcoreapp2.0" -adddFx "Microsoft.NetCore.App" -adddFxVer "2.0.0" -storeTFM "netcoreapp2.0";