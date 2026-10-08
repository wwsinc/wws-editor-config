# Wws.EditorConfig

[![nuget](https://img.shields.io/nuget/v/Wws.EditorConfig.svg?style=flat-square)](https://www.nuget.org/packages/Wws.EditorConfig/)
[![downloads](https://img.shields.io/nuget/dt/Wws.EditorConfig.svg?style=flat-square)](https://www.nuget.org/packages/Wws.EditorConfig/)
[![publish](https://github.com/wwsinc/wws-editor-config/actions/workflows/main.yml/badge.svg)](https://github.com/wwsinc/wws-editor-config/actions/workflows/main.yml)

One NuGet package that enforces the WWS coding standard in every .NET project: code style, analyzer severities, SonarAnalyzer and common build settings.

The package **enforces** the standard; it does not just suggest it. The shared `.editorconfig` is written to your solution folder on every local build. Local edits to that file get overwritten, so rule changes belong in this repository.

## Installation

Reference the package once for every project, in `Directory.Build.props` at the solution root:

```xml
<Project>
  <ItemGroup>
    <PackageReference Include="Wws.EditorConfig" Version="x.y.z" PrivateAssets="all" />
  </ItemGroup>
</Project>
```

With [Central Package Management](https://learn.microsoft.com/nuget/consume-packages/central-package-management), put the version in `Directory.Packages.props` instead:

```xml
<PackageVersion Include="Wws.EditorConfig" Version="x.y.z" />
```

The package is a development dependency. It never becomes a dependency of the packages you publish, and it ships no assembly.

## What you get

### Rules, enforced in two ways

| Where | How | What it covers |
| --- | --- | --- |
| Local builds (Visual Studio, Rider, `dotnet build`) | `.editorconfig` copied to the solution folder before compiling | Formatting, code style, naming, analyzer severities, plus folder-specific overrides. The IDE uses it too. |
| Every build, CI included | `.globalconfig` passed straight to the compiler | Code style, naming and analyzer severities for C# files |

The `.editorconfig` goes to the first location found:

1. The solution folder (`$(SolutionDir)`) when you build a solution.
2. The nearest folder above the project that contains a `.sln` or `.slnx`, when you build a project on its own. The search stops at the repository root.
3. The project folder, when there is no solution at all.

The file is only rewritten when its content differs from the packaged one. CI builds (`CI_BUILD=true` or Azure DevOps `TF_BUILD=true`) skip the copy, so the checkout stays untouched, and rely on the `.globalconfig`.

### SonarAnalyzer

[SonarAnalyzer.CSharp](https://www.nuget.org/packages/SonarAnalyzer.CSharp) comes as a pinned dependency of the package, so every consuming project restores it and runs it. That includes `dotnet build` and CI.

### Build settings

`build/Wws.EditorConfig.props` sets these for every consuming project:

| Property | Value |
| --- | --- |
| `Nullable` | `enable` |
| `WarningsAsErrors` | `nullable` (nullable warnings fail the build) |
| `ImplicitUsings` | `enable` |
| `GenerateDocumentationFile` | `true` (needed for IDE0005 in builds) |
| `EnforceCodeStyleInBuild` | `true` |
| `EnableNETAnalyzers` | `true` |
| `AnalysisMode` / `AnalysisLevel` | `All` / `latest` |
| `RunAnalyzersDuringBuild` / `RunAnalyzersDuringLiveAnalysis` | `true` |
| `TreatWarningsAsErrors` | `false` |

### Highlights of the standard

Errors (they fail the build):

- File-scoped namespaces (`csharp_style_namespace_declarations`)
- Braces on every `if`/`else`/loop (`csharp_prefer_braces`, Sonar S121)
- No unnecessary `using` directives (IDE0005)
- At most one blank line in a row (IDE2000)
- Rethrow with `throw;` (CA2200)

Naming (warnings):

- Private and internal fields: `_camelCase`
- Private and internal static fields: `s_camelCase`
- Constants: `PascalCase`

Relaxed areas:

- Folders named `test`, `samples`, `perf`, `scripts`, `stress` and similar get softer CA/IDE severities.
- `**/Migrations/*.cs` and `**/Contracts/**/*Mapper.cs` are exempt from some Sonar rules (S1192, S1133, S4226).

The full list is in [`Rules/Templates`](Wws.EditorConfig/Rules/Templates).

## Changing the rules

1. Edit the templates in `Wws.EditorConfig/Rules/Templates`:
   - `editorconfig.rules`: formatting, code style, naming, .NET analyzers
   - `sonar-analyzer.rules`: SonarAnalyzer severities
2. Build the project. This regenerates `Rules/.editorconfig` (the templates joined together) and `Rules/.globalconfig` (the `[*.cs]` and `[*.{cs,vb}]` sections, flattened). Commit both generated files with your change.
3. Run the smoke test (below).

The `.globalconfig` cannot hold path-specific sections. Overrides for `[**/Migrations/*.cs]` and similar only apply through the `.editorconfig`, so locally but not in CI.

## Testing

`tests/smoke/run.ps1` installs a freshly packed package into a throwaway solution and checks:

- `.editorconfig` lands in the solution folder and matches the packaged file
- An edited `.editorconfig` is overwritten before compiling, including when you build a project on its own
- CI builds skip the copy but still report the rules
- Sonar runs, and the package severities apply (S121 is raised to an error)

```powershell
dotnet pack Wws.EditorConfig/Wws.EditorConfig.csproj -c Release -o ./nuget
./tests/smoke/run.ps1 -PackageDirectory ./nuget
```

CI runs the smoke test on every push and pull request.

## Releasing

The package version comes from the git tag through [MinVer](https://github.com/adamralph/minver). Don't edit a version number in the project file.

1. Merge to `main`.
2. Create a GitHub release with a new tag such as `1.3.3` (no `v` prefix).
3. The `publish` workflow packs, validates, smoke-tests and pushes that version to nuget.org.

Builds between tags get a pre-release version such as `1.3.3-alpha.0.4`.

To upgrade SonarAnalyzer, change the `SonarAnalyzer.CSharp` version in `Wws.EditorConfig.csproj`. It's the only place the version is set.

## Links

- [Code analysis in .NET](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview)
- [Configuration files for code analysis rules](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/configuration-files)
- [EditorConfig](https://editorconfig.org/)
- [SonarAnalyzer rules for C#](https://rules.sonarsource.com/csharp/)
