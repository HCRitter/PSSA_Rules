<#
.SYNOPSIS
Analyzes PowerShell script blocks to ensure functions have examples in their help content.

.DESCRIPTION
The Measure-CommandExampleAnalyzer function checks PowerShell script blocks for function definitions and verifies that they include examples in their help content. It generates diagnostic records for functions that either lack examples or have examples that do not match the function name.

.PARAMETER ScriptBlockAst
The abstract syntax tree (AST) of the script block to be analyzed. This parameter is mandatory and cannot be null or empty.

.OUTPUTS
[Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]
Returns an array of diagnostic records indicating functions with missing or incorrect examples.

.EXAMPLE
$scriptBlockAst = [System.Management.Automation.Language.Parser]::ParseFile("path\to\script.ps1", [ref]$null, [ref]$null)
Measure-CommandExampleAnalyzer -ScriptBlockAst $scriptBlockAst

This example parses a script file into an AST and analyzes it for functions with missing or incorrect examples.

.NOTES
Author: Christian Ritter
Date: 10/2/2025

#>

function Measure-CommandExampleAnalyzer {
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
                
                if($Ast -is [System.Management.Automation.Language.FunctionDefinitionAst]){
                    if([string]::IsNullOrEmpty($AST.GetHelpContent().Examples)){
                        return $true
                    }else {
                        return $false
                    }
                }else{
                    return $false
                }
            }
            [ScriptBlock]$predicate2 = {
                param ([System.Management.Automation.Language.Ast]$Ast)
                
                if($Ast -is [System.Management.Automation.Language.FunctionDefinitionAst]){
                    $AST.GetHelpContent().Examples.ForEach({
                        if($_ -notlike "*$($Ast.Name)*"){
                            return $true
                        }
                    })
                    return $false
                }else{
                    return $false
                }
            }



            #endregion

            #region Finds ASTs that match the predicate.

            [System.Management.Automation.Language.Ast[]]$NoExampleAST = $ScriptBlockAst.FindAll($predicate1, $true)


            $NoExampleAST | ForEach-Object {
                [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                    "Message"              = "$(
                        ((Get-Command $_.Extent.File).ScriptBlock.Ast.FindAll(
                           { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] },
                          $false # parameter `searchNestedScriptBlocks`
                        )).Name
                    )" + " has no examples"
                    "Extent"               = $_.Extent
                    "RuleName"             = $PSCmdlet.MyInvocation.InvocationName
                    "Severity"             = "Warning"
                    "RuleSuppressionID"    = "1339" # Very creative, for sure.
                }
            }

            [System.Management.Automation.Language.Ast[]]$BadExampleAST = $ScriptBlockAst.FindAll($predicate2, $true)


            $BadExampleAST | ForEach-Object {
                [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                    "Message"              = "$(
                        ((Get-Command $_.Extent.File).ScriptBlock.Ast.FindAll(
                           { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] },
                          $false # parameter `searchNestedScriptBlocks`
                        )).Name
                    )" +  " has bad examples"
                    "Extent"               = $_.Extent
                    "RuleName"             = $PSCmdlet.MyInvocation.InvocationName
                    "Severity"             = "Warning"
                    "RuleSuppressionID"    = "1340" # Very creative, for sure.
                }
            }
            #endregion
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}
Export-ModuleMember -Function Measure-CommandExampleAnalyzer
