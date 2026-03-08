# TA-Ollama v0.1.3 Release Summary

## Release Information
- **Version**: 0.1.3
- **Release Date**: 2025-10-10
- **CIM Compliance**: CIM 5.0+ Web Datamodel

## Key Improvements

### 1. CIM 5.0+ Web Datamodel Compliance


**New Fields Added:**
- `bytes_in` / `bytes_out` - Request/response size tracking
- `http_user_agent` - Client identification (default: "Ollama-Client")
- `site` - Logical site grouping ("ollama_api")
- `dest_port` - Destination port (11434)
- `transport` - Network transport ("tcp")
- `protocol` - Application protocol ("http")
- `web_method` - HTTP method alias
- `http_content_type` - Response content type


### 2. Enhanced Field Extraction
**Improved IPv6 Support:**
- Now handles `::1` (localhost)
- Supports `::ffff:` prefix for IPv4-mapped IPv6
- Better regex pattern for mixed IPv4/IPv6 environments

### 3. Documentation Overhaul
- Enhanced `README.txt` for package

## Files Modified

### Configuration Files:
1. **app.conf** - Updated version to 0.1.3
2. **props.conf** - Added 12+ new EVAL statements for CIM fields
3. **transforms.conf** - Enhanced regex, improved IPv6 support
4. **app.manifest** - Updated metadata, release notes, CIM requirements





