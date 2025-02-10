<#
.SYNOPSIS
    Analyzes a PowerShell script to measure the usage of Microsoft Graph permission scopes.

.DESCRIPTION
    The Measure-GraphPermissionScope function inspects a given PowerShell script's Abstract Syntax Tree (AST) to identify the usage of Microsoft Graph permission scopes.
    It checks if the scopes specified in the 'Connect-MGGraph' command are actually used in the script and generates diagnostic records for any unused scopes.

.PARAMETER ScriptBlockAst
    The AST of the script block to be analyzed. This parameter is mandatory and cannot be null or empty.

.OUTPUTS
    [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]
    Returns an array of DiagnosticRecord objects indicating any unused permission scopes.

.EXAMPLE
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile("path\to\script.ps1", [ref]$null, [ref]$null)
    Measure-GraphPermissionScope -ScriptBlockAst $scriptAst

.NOTES
    Author: Christian Ritter (@HCRitter)
    Date: 10/2/2025
#>

function Measure-GraphPermissionScope {
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )
    Process {
        try {
            #region Define predicates to find ASTs.
            [ScriptBlock]$predicate1 = {
                param ([System.Management.Automation.Language.Ast]$Ast)
                if($Ast -is [System.Management.Automation.Language.CommandAst]){
                    if($Ast.CommandElements[0].Extent.Text -eq 'Connect-MGGraph'){
                        if($Ast.CommandElements | Where-Object { $_.Extent.Text -like '-Scopes' }){
                            return $true
                        }else{
                            return $false
                        }
                    }else{
                        return $false
                    }
                }else{
                    return $false
                }
                 
            }
            #endregion

            #region Finds ASTs that match the predicate.

            [System.Management.Automation.Language.Ast[]]$methodAst = $ScriptBlockAst.FindAll($predicate1, $true)

            $ReturnObject = $methodAst | ForEach-Object {
                $ScriptContent = Get-Content -Path $ScriptBlockAst.Extent.File -Raw
                $ScriptAST = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)

                $PossiblePermissions = $ScriptAST.FindAll({ param ($ast) $ast -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object {
                    if((Get-Command -Name $_.CommandElements[0].Extent.Text).Source -like 'Microsoft.Graph*'){
                        if($_.CommandElements[0].Extent.Text -ne "Connect-MGGraph"){
                            (Find-MGGraphCommand -Command $_.CommandElements[0].Extent.Text ).Permissions.Name
                        }
                        
                    }
                }
                $commandAst = $ScriptAST.Find({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.CommandElements[0].Extent.Text -eq 'Connect-MgGraph' }, $true)
                $ScopesParam = $commandAst.CommandElements | Where-Object { $_.Extent.Text -eq '-Scopes' }
                $ScopesValue = $commandAst.CommandElements[$commandAst.CommandElements.IndexOf($ScopesParam) + 1].Extent.Text
                $ConnectedPermissionScopes = $ScopesValue.split(",").Replace('"','')

                foreach($ConnectedPermissionScope in $ConnectedPermissionScopes){
                    if($PossiblePermissions -notcontains $ConnectedPermissionScope){
                        [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                            "Message" = "The permission scope '$ConnectedPermissionScope' is not used in the script."
                            "Extent"               = $_.Extent
                            "RuleName"             = $PSCmdlet.MyInvocation.InvocationName
                            "Severity"             = "Warning"
                            "RuleSuppressionID"    = "1338" # Very creative++, for sure.
                        }
                    }
                }
            }
            return $ReturnObject

            #endregion
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}
Export-ModuleMember -Function Measure-GraphPermissionScope
