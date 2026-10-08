using System;

namespace Smoke.Shared;

/// <summary>
/// The unnecessary using above is an IDE0005 error everywhere except **/Shared/**.cs, where the package rules turn it off.
/// The smoke test fails if that folder-specific override is not applied.
/// </summary>
public static class SharedCode
{
    /// <summary>Returns a constant.</summary>
    /// <returns>Always 1.</returns>
    public static int One() => 1;
}
