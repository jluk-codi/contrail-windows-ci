﻿function Repair-NUnitReport {
    Param([Parameter(Mandatory = $true)] [string] $InputData)
    [xml] $XML = $InputData

    $CaseNodes = Find-CaseNodes -XML $XML
    Set-DescriptionAndNameTheSameFor -Nodes $CaseNodes

    FlattenParametrizedTests -Xml $XML

    $SuiteNodesWithCases = Get-DirectSuiteParentsOf -Nodes $CaseNodes
    $SuiteNodesWithCases | Foreach-Object { $XML.'test-results'.AppendChild($_) } | Out-Null

    $SuiteNodesWithoutCases = Find-SuiteNodesWithoutCases -XML $XML
    Remove-Nodes -Nodes $SuiteNodesWithoutCases

    return $XML.OuterXml
}

function Find-CaseNodes {
    Param([Parameter(Mandatory = $true)] [xml] $XML)
    $XPath = "//test-case"
    $Selection = $XML | Select-Xml -XPath $Xpath
    $Nodes = @()
    $Nodes += ($Selection | ForEach-Object { $_.Node })
    # use coma notation to return empty array if nothing was selected.
    return ,$Nodes
}

function Get-DirectSuiteParentsOf {
    Param([Parameter(Mandatory = $true)] [AllowEmptyCollection()]
          [System.Xml.XmlElement[]] $Nodes)
    $Arr = @()
    $Arr += $Nodes | ForEach-Object {
        $_.ParentNode.ParentNode
    }
    return ,$Arr
}

function FlattenParametrizedTests {
    Param([Parameter(Mandatory = $true)] [xml] $XML)
    $ParametrizedTests = $XML | Select-Xml -Xpath '//test-suite[@type="ParameterizedTest"]/results/*'
    foreach ($TestCase in $ParametrizedTests | Foreach-Object { $_.Node }) {
        $TestCase.ParentNode.ParentNode.ParentNode.AppendChild($TestCase) | Out-Null
    }
}

function Set-DescriptionAndNameTheSameFor {
    Param([Parameter(Mandatory = $true)] [AllowEmptyCollection()]
          [System.Xml.XmlElement[]] $Nodes)
    $Nodes | ForEach-Object {
        if ($_.Attributes['description']) {
            $_.name = $_.description
        }
    } | Out-Null
}

function Find-SuiteNodesWithoutCases {
    Param([Parameter(Mandatory = $true)] [xml] $XML)
    $XPath = "//test-suite[not(.//test-case)]"
    $Selection = $XML | Select-Xml -XPath $Xpath
    $Nodes = @()
    $Nodes += ($Selection | ForEach-Object { $_.Node })
    return ,$Nodes
}

function Remove-Nodes {
    Param([Parameter(Mandatory = $true)] [AllowEmptyCollection()]
          [System.Xml.XmlElement[]] $Nodes)
    $Nodes | ForEach-Object {
        $_.ParentNode.RemoveChild($_)
    } | Out-Null
}
