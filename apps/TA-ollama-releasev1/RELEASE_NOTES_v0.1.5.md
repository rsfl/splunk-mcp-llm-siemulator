# Release Notes - TA-ollama v0.1.5

## Version 0.1.5 - December 5, 2025

### Bug Fixes
- **Fixed event line breaking**: Updated props.conf to break events on time boundaries rather than GIN pattern, ensuring proper event segmentation for both GIN web logs and standard Ollama logs
- **Improved time extraction**: Added TIME_PREFIX and MAX_TIMESTAMP_LOOKAHEAD settings to handle both GIN format (`[GIN] 2025/10/02 - 15:27:51`) and standard Ollama format (`time=2025-10-02T15:27:04.627-04:00`)
- **Enhanced field extraction**: Updated regex in transforms.conf to better handle variable-width padding in GIN logs (IPv4 vs IPv6 spacing differences)
- **Fixed whitespace handling**: Added trim() operations for src and response_time fields to remove GIN's visual alignment padding
- **Extended time parsing**: Updated response_time_ms calculation to handle compound time formats (e.g., "15m29s" for long-running operations like model downloads)

### CIM Compliance Enhancements
- **Added `method` field**: Standard CIM Web datamodel field alias for http_method
  - Improves compatibility with CIM-compliant searches and dashboards
  - Better integration with Splunk Enterprise Security (ES)
- **Added `code_source` field**: Extracts Go source file locations from structured logs (e.g., `server.go:1332`)
  - Useful for troubleshooting and debugging Ollama internals
  - Avoids conflict with Splunk's built-in `source` metadata field
- **Improved `uri_query` extraction**: Dynamic extraction instead of hardcoded empty string
  - Properly extracts query parameters when present
  - Returns null when no query string exists

### Technical Changes
- `props.conf`: Added `TIME_PREFIX` and `MAX_TIMESTAMP_LOOKAHEAD` for better timestamp detection
- `transforms.conf`: Simplified regex pattern to use non-greedy matching for fields with variable spacing
- `props.conf`: Added EVAL statements to trim whitespace from extracted fields
- `props.conf`: Enhanced response_time_ms calculation to handle minutes+seconds format
- `props.conf`: Added `FIELDALIAS-cim_web_method = http_method AS method`
- `props.conf`: Added `EVAL-code_source` for Go source file extraction
- `props.conf`: Updated `EVAL-uri_query` for dynamic extraction

### Impact
These changes resolve issues with:
- Duplicate events in search results
- Incorrect event boundaries when GIN and non-GIN logs are mixed
- Field extraction failures for IPv6 addresses with different spacing
- Inaccurate response time calculations for long-duration requests (>60 seconds)

### Compatibility
- Fully backward compatible with existing installations
- No index changes required
- Existing saved searches and dashboards will continue to work
- Splunkbase package structure maintained

### Testing Recommendations
After upgrade, verify:
1. No duplicate events in search results: `index=main | stats count by _time, _raw | where count > 1`
2. Field extractions working: `index=main "[GIN]" | stats count by src, http_method, uri_path`
3. Time parsing correct for long requests: `index=main "[GIN]" response_time="*m*s" | table _time, response_time, response_time_ms`

### Known Issues
None

### Upgrade Instructions
1. Remove existing TA-ollama v0.1.4
2. Install TA-ollama v0.1.5
3. Restart Splunk
4. No reindex required (changes affect search-time only)
