<#
.SYNOPSIS
    Given a GitHub PullRequest ID, this generates a file containing a list of files that were changed
    in that pull request.
.DESCRIPTION
    Generates a file containing a list of all modified files (added/removed/modified) in
    the given pull request. The output file contains a list that is newline delimited, for
    example:

    Assets/MixedRealityToolkit.SDK/AssemblyInfo.cs
    Assets/MixedRealityToolkit.Tests/PlayModeTests/ManipulationHandlerTests.cs

.PARAMETER Username
    The username associated with the Personal Access Token. This is optional in that
    the script will exit early if not provided, since not all pipelines will be configured
    to generate this list of changed files.
.PARAMETER Token
    The Personal Access Token generated explicitly with "(no scope)" - meaning only public
    information should be granted to this token.. This is optional in that
    the script will exit early if not provided, since not all pipelines will be configured
    to generate this list of changed files.
.PARAMETER Output
    The output filename containing the list of modified files.
.EXAMPLE
    .\validatecode.ps1 -Directory c:\path\to\MRTK\Assets
#>
param(
    [string]$Username,
    [string]$Token,
    [Parameter(Mandatory=$true)]
    [string]$Output,
    [Parameter(Mandatory=$true)]
    [string]$PullRequestId
)

# Both $Username and $Token are actually required inputs to this script, but may not
# be set for all of the pipelines that we run - for the cases where it's not set (i.e.
# intentionally not set), this script should fail gracefully and produce no output.
if ([string]::IsNullOrEmpty($Username) -or [string]::IsNullOrEmpty($Token))
{
    Write-Host "Username and Token are not both present, skipping."
    exit 0;
}

# If the output file already exists, blow it away.
# Each run should get a new set of changed files.
if (Test-Path $Output -PathType leaf) {
    Remove-Item $Output
}

# For the time being, we use the Github API directly instead of using an API layer
# like https://github.com/microsoft/PowerShellForGitHub or PyGithub, which could 
# greatly simplify this story. This may pull in some other module/installs which need
# to be validated against the pipeline infrastructure.
# This section uses basic auth (against the GitHub https target) using the instructions here:
# https://developer.github.com/v3/auth/
$BasicAuthenticationBase64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(($Username + ":" + $Token)))
$Headers = @{ Authorization = "Basic $BasicAuthenticationBase64" }

# The output of this API call is documented here:
# https://developer.github.com/v3/pulls/#list-pull-requests-files
$Uri = "https://api.github.com/repos/microsoft/MixedRealityToolkit-Unity/pulls/$PullRequestId/files"
$Response = Invoke-WebRequest -Uri $Uri -Headers $Headers -UseBasicParsing

# Content comes back as a raw JSON string, which must be converted into object form.
$ParsedResponse = ConvertFrom-Json $Response.content

foreach ($FileInfo in $ParsedResponse) {
    Add-Content -Path $Output -Value $FileInfo.filename
}
