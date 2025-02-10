<#
.SYNOPSIS
Analyzes PowerShell scripts to identify variable names using snake_case.

.DESCRIPTION
This function takes a ScriptBlockAst as input and analyzes it to find variable names that use snake_case. It returns diagnostic records for each instance found, suggesting the use of camelCase or PascalCase instead. This can help enforce coding standards and improve code readability.

.PARAMETER ScriptBlockAst
Specifies the abstract syntax tree (AST) of the script block to analyze. This parameter is mandatory.

.EXAMPLE
>Invoke-ScriptAnalyzer -CustomRulePath .\Rules\Measure-SnakeCaseVariableNames.psm1 -Path .\test.ps1

This example parses a script file and analyzes it for snake_case variable names.

.NOTES
Author: Christian Ritter (@HCRitter)
Date: 10/2/2025
Version: 1.0

#>
function Measure-SnakeCaseVariableNames {
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
                if ($Ast -is [System.Management.Automation.Language.AssignmentStatementAst]) {
                    if ($Ast.Left -is [System.Management.Automation.Language.VariableExpressionAst]) {   
                        if ($Ast.Left.VariablePath.UserPath -match '^[a-z]+_[a-z]+(?:_[a-z]+)*$') {
                            return $true
                        }
                    }
                }else{
                    return $false
                }
            }

            #endregion

            #region Finds ASTs that match the predicate.

            [System.Management.Automation.Language.Ast[]]$methodAst = $ScriptBlockAst.FindAll($predicate1, $true)

            $ResultHT = @{}
            $methodAst | ForEach-Object {
                $ResultHT[$_.Extent] = [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                    "Message"              = "Snake_case variable names are not best practice, use: $(
                        -join $((($_.Extent.ToString()).split('=')[0])).split('_').ForEach({
                            (Get-Culture).TextInfo.ToTitleCase($_)
                        })
                    )"
                    "Extent"               = $_.Extent
                    "RuleName"             = $PSCmdlet.MyInvocation.InvocationName
                    "Severity"             = "Warning"
                    "RuleSuppressionID"    = "1337" # Very creative, for sure.
                }
            }
            return $resultHT.Values

            #endregion
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}
Export-ModuleMember -Function Measure-SnakeCaseVariableNames
