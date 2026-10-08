namespace Smoke;

/// <summary>Deliberate rule violations the smoke test expects the package to report.</summary>
public static class Violations
{
    /// <summary>Triggers S1481 and S121 (SonarAnalyzer, S121 raised to error) and IDE0011 (code style from the package rules).</summary>
    /// <param name="value">Any value.</param>
    /// <returns>The value when positive, otherwise zero.</returns>
    public static int Run(int value)
    {
        var unused = 42;
        if (value > 0)
            return value;
        return 0;
    }
}
