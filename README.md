# VsPowershellLib

A collection of powershell macros for Visual Studio.

## Installing

1. Clone the repository into **C:\Users\%your-user%\Documents\WindowsPowerShell**
1. Restart Visual Studio or execute the following command inside Package Manager Console:
`
PM> . 'C:\Users\%your-user%\Documents\WindowsPowerShell\NuGet_profile.ps1'
`

## Usage

Inside the Package Manager Console, execute the functions that are available inside the powershell files. When a function manipulates source code, the current type is the type that contains the location of the cursor in the currently open file.

## Examples

### Move the current type to a file named after that type

1. Place the cursor inside the desired type.
1. `PM> Move-TypeToOwnFile`

### Add a constructor argument, a private field and initialize the field from the argument

1. Place the cursor inside the desired type.
1. `PM> Add-Dependency IMyDependency`

### Delete a project configuration in every project in the solution

1. `PM> Get-Projects | % { $_.ConfigurationManager.DeleteConfigurationRow('PreRelease') }`

### Set the target framework of every project in the solution to .NET 4.5

1. `PM> Get-Projects | % { $_.Properties.Item("TargetFramework").Value = 262149 }`

### Downgrade a NuGet package to an older version

1. `Downgrade-Package SixPack 1.2.3`

This will uninstall any installed package named 'SixPack' with a version number greater than '1.2.3'. And install that version instead. 

### Increment the package version number of the specified project and the minor version of all dependent packages

1. `Increment-PackageVersion MyProject Major`
1. `Increment-PackageVersion MyProject Minor`
1. `Increment-PackageVersion MyProject Build`

This assumes that the package version is stored in a file named '_Package.cs' with the following structure:

    internal static class Package
    {
        public const string Name = "MyPackage";
        public const string Version = "2.0.24";
    }
