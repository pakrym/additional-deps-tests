function assert($text, $skip)
{
    if (!($log -like "*$text*"))
    {
        if ($skip)
        {
            Write-Warning "Output didn't contain $text. Skipped: $skip"
        }
        else {
            Write-Error "Output didn't contain $text"
        }
    }
}

function hs($adddFx, $adddFxVer, $storeTFM, $hsName, $hsVer, $dependencyVersion)
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
    $dependencyName = "Microsoft.Extensions.DependencyInjection.Abstractions";
    $hsList.Add($hsName);

    $storeLibDir = "$storeDir\x64\$storeTFM\$hsName\$hsVer\";
    dotnet publish src\hs\hs.csproj -o $storeLibDir -p:Version=$hsVer -p:AssemblyName=$hsName -p:DependencyVersion=$dependencyVersion > "$dirName\publish.$hsName.log";

    if ($dependencyVersion)
    {
        $ddir = "$storeLibDir\..\..\$dependencyName\$dependencyVersion\lib\netstandard2.0\";
        mkdir $ddir > $null;
        Move-Item $storeLibDir\$dependencyName.dll "$ddir\$dependencyName.dll" > $null;
    }

    $adddLibDir = "$adddDir\shared\$adddFx\$adddFxVer";
    mkdir $adddLibDir | Out-Null;
    Copy-Item "$storeLibDir\$hsName.deps.json" $adddLibDir;
}

function test($name, $appFx, $appFxVer, $appTfm, $hs, $verify, $dependencyVersion)
{
    $dirName = Join-Path -Path $PSScriptRoot -ChildPath "test-$name";
    Write-Host "Testing $appTfm $appFx $appFxVer" -ForegroundColor Green;

    mkdir $dirName | Out-Null;

    $appDir = Join-Path -Path $dirName -ChildPath "app";
    dotnet publish src\app\app.csproj -f $appTfm -o $appDir -p:DependencyVersion=$dependencyVersion > "$dirName\publish.app.log";

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
    "`$env:COREHOST_TRACE = 1;" | Out-File $runFile -Append
    "dotnet `"$appDir\app.dll`" $hsList 2>`"$dirName\corehost.log`"" | Out-File $runFile -Append

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
<#
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

#>
$currentANCA = "2.1.0-rtm-30700"
$currentMNCA = "2.1.0-rc1-26423-06";

test -name "Deps-downgrade-app-upgrade" `
-appFx "Microsoft.AspNetCore.App" `
-appFxVer "$currentANCA" `
-appTfm "netcoreapp2.1" `
-dependencyVersion "2.2.0-preview1-34096" `
{
    hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0-preview1" -storeTFM "netcoreapp2.1" -hsName "dnchs" -dependencyVersion 2.2.0-preview1-34097;
}`
{
   assert "ROOT\dotnet\shared\Microsoft.AspNetCore.App\$currentANCA\Microsoft.AspNetCore.App.deps.json"
   assert "/app/Microsoft.Extensions.DependencyInjection.Abstractions.dll"
   assert "TESTROOT\store\x64\netcoreapp2.1\dnchs\2.1.0-preview1\dnchs.dll";
}


test -name "Downgrade-app-with-hs" `
-appFx "Microsoft.AspNetCore.App" `
-appFxVer "$currentANCA" `
-appTfm "netcoreapp2.1" `
-dependencyVersion 2.1.0-preview1-final `
{
    hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0-preview1" -storeTFM "netcoreapp2.1" -dependencyVersion 2.0.0;
}`
{
   assert "ROOT\dotnet\shared\Microsoft.AspNetCore.App\$currentANCA\Microsoft.AspNetCore.App.deps.json"
   assert "app/Microsoft.Extensions.DependencyInjection.Abstractions.dll"
   assert "TESTROOT\store\x64\netcoreapp2.1\hs\2.1.0-preview1\hs.dll";
}

test -name "Downgrade-fx-with-hs" `
-appFx "Microsoft.AspNetCore.App" `
-appFxVer "$currentANCA" `
-appTfm "netcoreapp2.1" `
{
    hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0-preview1" -storeTFM "netcoreapp2.1" -dependencyVersion 2.0.0;
}`
{
   assert "ROOT\dotnet\shared\Microsoft.AspNetCore.App\$currentANCA\Microsoft.AspNetCore.App.deps.json"
   assert "shared/Microsoft.AspNetCore.App/$currentANCA/Microsoft.Extensions.DependencyInjection.Abstractions.dll" -skip "Seems like a bug"
   assert "TESTROOT\store\x64\netcoreapp2.1\hs\2.1.0-preview1\hs.dll";
}

test -name "Multiple-dep-versions-in-hs" `
-appFx "Microsoft.AspNetCore.App" `
-appFxVer "$currentANCA" `
-appTfm "netcoreapp2.1" `
{
    hs -adddFx "Microsoft.AspNetCore.App" -adddFxVer "2.1.0-preview1" -storeTFM "netcoreapp2.1" -dependencyVersion 2.0.0;
    hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0-preview1" -storeTFM "netcoreapp2.1" -hsName "dnchs" -dependencyVersion 2.2.0-preview1-34097;
}`
{
   assert "ROOT\dotnet\shared\Microsoft.AspNetCore.App\$currentANCA\Microsoft.AspNetCore.App.deps.json"
   assert "/microsoft.extensions.dependencyinjection.abstractions/2.2.0-preview1-34097"
   assert "TESTROOT\store\x64\netcoreapp2.1\hs\2.1.0-preview1\hs.dll";
   assert "TESTROOT\store\x64\netcoreapp2.1\dnchs\2.1.0-preview1\dnchs.dll";
}

# storeTFM should be 2.0 or any
test -name "$currentMNCA-app_2.2.0_deps" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "$currentMNCA" `
     -appTfm "netcoreapp2.1" `
     {
        hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0-preview1-26500-00" -storeTFM "netcoreapp2.1";
        hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0-preview1-26501-00" -storeTFM "netcoreapp2.1"; } `
     {
        assert "ROOT\dotnet\shared\Microsoft.NetCore.App\$currentMNCA\Microsoft.NetCore.App.deps.json";
        assert "TESTROOT\store\x64\netcoreapp2.1\hs\2.1.0-preview1-26501-00\hs.dll";
     }

test -name "$currentMNCA-app_2.2.0-preview1_deps" `
     -appFx "Microsoft.NetCore.App" `
     -appFxVer "$currentMNCA" `
     -appTfm "netcoreapp2.1" `
     {
        hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.0.0" -storeTFM "netcoreapp2.0";
        hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0-preview1" -storeTFM "netcoreapp2.1";
        hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0" -storeTFM "netcoreapp2.1";
     }`
     {
         assert "ROOT\dotnet\shared\Microsoft.NetCore.App\$currentMNCA\Microsoft.NetCore.App.deps.json";
         assert "TESTROOT\store\x64\netcoreapp2.1\hs\2.1.0-preview1\hs.dll";
     }


test -name "$currentANCA-app_2.0.0_deps" `
-appFx "Microsoft.AspNetCore.App" `
-appFxVer "$currentANCA" `
-appTfm "netcoreapp2.1" `
{
    hs -adddFx "Microsoft.AspNetCore.App" -adddFxVer "2.1.0-preview1" -storeTFM "netcoreapp2.1";
    hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0-preview1" -storeTFM "netcoreapp2.1" -hsName "dnchs";
}`
{
   assert "ROOT\dotnet\shared\Microsoft.AspNetCore.App\$currentANCA\Microsoft.AspNetCore.App.deps.json"
   assert "TESTROOT\store\x64\netcoreapp2.1\hs\2.1.0-preview1\hs.dll";
   assert "TESTROOT\store\x64\netcoreapp2.1\dnchs\2.1.0-preview1\dnchs.dll";
}

test -name "$currentANCA-newer-deps" `
-appFx "Microsoft.AspNetCore.App" `
-appFxVer "$currentANCA" `
-appTfm "netcoreapp2.1" `
{
    hs -adddFx "Microsoft.AspNetCore.App" -adddFxVer "2.1.0-preview1" -storeTFM "netcoreapp2.1";
    hs -adddFx "Microsoft.AspNetCore.App" -adddFxVer "2.1.0-klm" -storeTFM "netcoreapp2.1";
    hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0-preview1" -storeTFM "netcoreapp2.1" -hsName "dnchs";
    hs -adddFx "Microsoft.NetCore.App" -adddFxVer "2.1.0-klm" -storeTFM "netcoreapp2.1" -hsName "dnchs";
}`
{
   assert "ROOT\dotnet\shared\Microsoft.AspNetCore.App\$currentANCA\Microsoft.AspNetCore.App.deps.json"
   assert "TESTROOT\store\x64\netcoreapp2.1\hs\2.1.0-preview1\hs.dll";
   assert "TESTROOT\store\x64\netcoreapp2.1\dnchs\2.1.0-preview1\dnchs.dll";
}
