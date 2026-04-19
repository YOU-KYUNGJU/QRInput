ShouldProcessRow(rowObj, teamCfg) {
    eligibility := EvaluateRowEligibility(rowObj, teamCfg)
    return eligibility.should_process
}

EvaluateRowEligibility(rowObj, teamCfg) {
    scanCol := teamCfg.row_scan_column
    if (scanCol = "")
        scanCol := (teamCfg.receipt_mode = "direct") ? "B" : "A"

    scanValue := NormalizeCellValue(GetRowValue(rowObj, scanCol))
    pattern := Trim(teamCfg.row_scan_pattern)
    result := {should_process: false, reason: "", scan_column: scanCol, scan_value: scanValue, pattern: pattern}

    if (scanValue = "") {
        result.reason := "empty_scan_column"
        return result
    }

    if (pattern != "" && !RegExMatch(scanValue, pattern)) {
        result.reason := "scan_pattern_mismatch"
        return result
    }

    if (teamCfg.receipt_mode = "compose") {
        if (NormalizeCellValue(GetRowValue(rowObj, "A")) = "") {
            result.reason := "compose_missing_A"
            return result
        }
        if (NormalizeCellValue(GetRowValue(rowObj, "B")) = "") {
            result.reason := "compose_missing_B"
            return result
        }
        if (NormalizeCellValue(GetRowValue(rowObj, "D")) = "") {
            result.reason := "compose_missing_D"
            return result
        }
    }

    result.should_process := true
    result.reason := "eligible"
    return result
}

ExtractReceipt(rowObj, teamCfg) {
    result := {status: "ok", value: "", reason: ""}

    if (teamCfg.receipt_mode = "direct") {
        directCol := teamCfg.receipt_direct_column
        if (directCol = "")
            directCol := "B"

        value := NormalizeCellValue(GetRowValue(rowObj, directCol))
        if (value = "") {
            result.status := "invalid"
            result.reason := "direct_empty"
            return result
        }

        if !RegExMatch(value, "^@[A-Z][A-Z0-9]+@$") {
            result.status := "invalid"
            result.reason := "direct_pattern_mismatch"
            return result
        }

        result.value := value
        return result
    }

    if (teamCfg.receipt_mode = "compose") {
        parts := StrSplit(teamCfg.receipt_compose_columns, ",")
        composed := "@"

        for _, partCol in parts {
            cellValue := NormalizeCellValue(GetRowValue(rowObj, Trim(partCol)))
            if (cellValue = "") {
                result.status := "invalid"
                result.reason := "compose_missing_" . Trim(partCol)
                return result
            }
            composed .= cellValue
        }

        composed .= "@"
        if !RegExMatch(composed, "^@[A-Z][A-Z0-9]+@$") {
            result.status := "invalid"
            result.reason := "compose_pattern_mismatch"
            return result
        }

        result.value := composed
        return result
    }

    result.status := "invalid"
    result.reason := "unsupported_receipt_mode"
    return result
}

BuildUniqueKey(teamName, csvPath, rowNo, receiptNo) {
    return teamName "|" csvPath "|" rowNo "|" receiptNo
}

GetRowValue(rowObj, columnName) {
    if (columnName = "")
        return ""
    return rowObj.HasKey(columnName) ? rowObj[columnName] : ""
}

NormalizeCellValue(value) {
    value := Trim(value, " `t`r`n")
    return ToUpper(value)
}
