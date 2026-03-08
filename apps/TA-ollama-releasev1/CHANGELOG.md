# CHANGELOG

## Version 0.1.5 (2025-12-04)

### Bug Fixes
- **Event Line Breaking**: Fixed event segmentation to break on time boundaries instead of GIN pattern
  - Added `TIME_PREFIX` to handle both GIN and standard Ollama log time formats
  - Added `MAX_TIMESTAMP_LOOKAHEAD` for improved timestamp detection
  - Prevents duplicate events and incorrect multi-line event creation

- **Field Extraction Improvements**:
  - Updated regex in transforms.conf to handle variable-width padding in GIN logs
  - Added trim() operations for `src` and `response_time` fields to remove visual alignment padding
  - Better handling of IPv4 vs IPv6 spacing differences in GIN output

- **Time Parsing Enhancements**:
  - Extended `response_time_ms` calculation to handle compound time formats (e.g., "15m29s")
  - Properly converts long-duration requests (model downloads, complex generations)
  - Fixes inaccurate time calculations for requests exceeding 60 seconds

### CIM Compliance Enhancements
- **Added `method` field**: Standard CIM Web datamodel field alias for http_method
  - Improves compatibility with CIM-compliant searches and dashboards
  - Better integration with Splunk Enterprise Security (ES)

- **Added `code_source` field**: Extracts Go source file locations from structured logs
  - Example: `server.go:1332`, `sched.go:517`
  - Useful for troubleshooting and debugging Ollama internals
  - Avoids conflict with Splunk's built-in `source` metadata field

- **Improved `uri_query` extraction**: Dynamic extraction instead of hardcoded empty string
  - Properly extracts query parameters when present (e.g., `/api/models?name=llama`)
  - Returns null when no query string exists

### Configuration Fixes
- **inputs.conf.spec Universal Forwarder Compatibility**: Fixed stanza conflict with Universal Forwarder
  - Removed explicit `[monitor://<path>]` stanza definition from inputs.conf.spec
  - Converted monitor configuration to documentation comments only
  - Resolves "conflicts with splunk stanza" error on Universal Forwarder deployments
  - Added reference to GitHub documentation for Linux log collection setup
  - No functional impact - monitor inputs continue to work as expected

### Technical Changes
- Modified `props.conf`:
  - Added TIME_PREFIX, MAX_TIMESTAMP_LOOKAHEAD, and field trimming EVALs
  - Added `FIELDALIAS-cim_web_method = http_method AS method`
  - Added `EVAL-code_source` for Go source file extraction
  - Updated `EVAL-uri_query` for dynamic extraction
- Modified `transforms.conf`: Simplified regex with non-greedy matching for variable spacing
- No reindex required (search-time only changes)

### Testing & Validation
- Verified HEC integration with ollama:prompts and ollama:api sourcetypes
- Tested field extraction with multiple log formats (GIN HTTP logs, structured logs)
- Validated CIM Web datamodel compliance
- Confirmed all core and extended CIM fields are properly populated

### Impact
- Resolves duplicate event issues
- Improves accuracy for long-running operation detection
- Better data quality for security detections and analytics
- Enhanced CIM compliance for enterprise deployments
- Improved Splunkbase standards adherence

## Version 0.1.4 (2025-11-20)

### Bug Fixes
- **AWS Splunk Compatibility**: Fixed transform validation error with `ollama_static_cim_fields`
  - Migrated static CIM field assignments from transforms.conf to EVAL statements in props.conf
  - Resolves "regex has no capturing groups, but FORMAT has capturing group references" error
  - Improves cross-platform compatibility across all Splunk deployments

### Improvements
- More efficient static field assignment using EVAL instead of REPORT transforms
- Simplified configuration with all field mappings consolidated in props.conf

## Version 0.1.3 (2025-10-10)

### CIM 5.0+ Compliance Enhancements
- **Web Datamodel Compliance**: Improved CIM 5.0+ Web datamodel fields
  - Added `bytes_in` and `bytes_out` fields (set to 0 for API logs)
  - Added `http_user_agent` with default "Ollama-Client"
  - Added `http_referrer`, `site`, `dest_port`, `transport`, `protocol`
  - Added `web_method`, `uri_query`, `http_content_type`
  - Enhanced `action` field to "allowed" for better CIM compliance

### Field Extraction Improvements
- Improved IPv6 support in regex patterns (handles ::ffff: prefix)
- Enhanced static field mappings with `product` field
- Added `vendor_action` for action field aliasing
- Better null handling for optional fields

### Tags Enhancement
- Added `communicate` tag to ollama_server eventtype for better categorization

### Documentation
- Updated version to 0.1.3 in app.conf
- Enhanced description to reflect full CIM 5.0+ compliance

## Version 0.1.2
- Initial CIM Web datamodel support
- Basic field extractions for GIN logs
- Security redactions for emails and API keys

## Version 0.1.1
- Initial release
- File monitoring support
- HEC integration
- Basic Ollama log parsing
