================================================================================
Splunk Technology Add-on for Model Context Protocol (MCP)
================================================================================

Version: 0.1.2
Author: Rod Soto <rod@rodsoto.net>
License: MIT
Source: mcp:jsonrpc

================================================================================
OVERVIEW
================================================================================

The TA-mcp-jsonrpc Technology Add-on enables Splunk to ingest, parse, and
analyze JSON-RPC protocol messages from Model Context Protocol (MCP) servers.
MCP servers provide AI assistants with tool capabilities like file operations,
API access, database queries, and more.

This TA provides:
- Standardized field extractions for JSON-RPC messages
- Pre-configured sourcetypes for MCP protocol data
- CIM compliance for Web data model (CIM 5.3)


================================================================================
WHAT IS MCP?
================================================================================

Model Context Protocol (MCP) is an open protocol that enables AI assistants
(like Claude) to securely interact with external tools and data sources. MCP
servers expose capabilities through a JSON-RPC 2.0 protocol over stdin/stdout.

Popular MCP Servers:
- Filesystem (@modelcontextprotocol/server-filesystem) - File operations
- GitHub (@modelcontextprotocol/server-github) - Repository management
- Memory (@modelcontextprotocol/server-memory) - Knowledge graph storage
- Fetch (@modelcontextprotocol/server-fetch) - Web content retrieval
- Git (@modelcontextprotocol/server-git) - Git repository tools
- Plus hundreds of community and enterprise servers

================================================================================
TESTING & VALIDATION
================================================================================

This TA has been tested and validated with real MCP server data

================================================================================
INSTALLATION
================================================================================

1. Install the TA

   Option A: Splunk Web
   1. Download TA-mcp-jsonrpc-0.1.2.tar.gz
   2. Navigate to Apps → Manage Apps → Install app from file
   3. Upload the tarball
   4. Restart Splunk

   Option B: Command Line
   # Extract to Splunk apps directory
   cd $SPLUNK_HOME/etc/apps
   tar xzf TA-mcp-jsonrpc-0.1.2.tar.gz
   $SPLUNK_HOME/bin/splunk restart

   Option C: Deployment Server
   # Deploy to forwarders
   cp -r TA-mcp-jsonrpc $SPLUNK_HOME/etc/deployment-apps/
   $SPLUNK_HOME/bin/splunk reload deploy-server

2. Configure Data Collection

   Choose the collection method that fits your environment.

================================================================================
DATA COLLECTION METHODS
================================================================================
This Technology Add-on requires MCP servers to output JSON-RPC 2.0 protocol messages in JSON format. Configure your MCP servers to write JSON-RPC messages to log files that Splunk can monitor with the mcp:jsonrpc sourcetype.

Configure Splunk input:
   [monitor://C:\ProgramData\mcp\logs\*.jsonl]
   disabled = false
   sourcetype = mcp:jsonrpc
   index = mcp

Method 2: File Redirection (Simple)
------------------------------------

Redirect MCP server stdout directly to files using tee or similar tools.

Method 3: Direct Upload (Testing)
----------------------------------

For testing with existing log files:
splunk add oneshot /path/to/mcp-filesystem.log -sourcetype mcp:jsonrpc -index mcp

================================================================================
SOURCETYPES
================================================================================

mcp:jsonrpc (Primary)
---------------------

Pure JSON-RPC protocol messages from MCP servers.

Sample Event:
{
  "jsonrpc": "2.0",
  "id": 42,
  "method": "tools/call",
  "params": {
    "name": "read_file",
    "arguments": {
      "path": "/etc/passwd"
    }
  }
}

Extracted Fields (40+):
- jsonrpc - Protocol version (always "2.0")
- id - Request/response correlation ID
- method - RPC method name
- params.name - Tool name being called
- params.arguments.* - Tool parameters (file paths, API calls, etc.)
- result.content{}.text - Operation results
- result.isError - Error indicator
- result.serverInfo.name - MCP server name
- result.serverInfo.version - MCP server version

Automated Extractions:
- JSON auto-parsing with INDEXED_EXTRACTIONS = json
- Automatic field extraction for all JSON keys
- Deep JSON path support (e.g., result.content{}.text)

claude:mcp:debug (Auxiliary)
-----------------------------

Claude Code debug logs containing MCP activity.

Sample Event:
2025-12-15T15:59:05.860Z [ERROR] MCP server "filesystem" Server stderr:
Secure MCP Filesystem Server running on stdio

Extracted Fields:
- timestamp - ISO 8601 timestamp
- log_level - DEBUG, ERROR, INFO, WARN
- mcp_server_name - Server name
- mcp_event - Connection status, tool calls
- connection_time_ms - Connection establishment time

================================================================================
FIELD EXTRACTIONS
================================================================================

Protocol Fields:
- mcp.jsonrpc_version - Protocol version
- mcp.id - Request/response correlation
- mcp.method - RPC method name
- mcp.message_type - request, response, notification, error

Tool Context:
- mcp.tool_name - Tool being called
- mcp.tool_action - Categorized action
- mcp.server_name - MCP server name
- mcp.client_name - Client application name

Security-Critical Fields:
- mcp.file_path - File being accessed
- mcp.file_operation - read, write, delete, search
- mcp.github_owner - GitHub repository owner
- mcp.github_repo - GitHub repository name
- mcp.github_action - GitHub operation type
- mcp.has_sensitive_operation - Flag for risky operations

Error Tracking:
- mcp.has_error - Error indicator
- mcp.error_code - JSON-RPC error code
- mcp.error_message - Error description

================================================================================
SECURITY DETECTION USE CASES EXAMPLES
================================================================================

1. Suspicious File Access - Detects access to sensitive files
2. Excessive File Writes - Identifies data staging activity
3. GitHub Code Push - Monitors external repository pushes
4. Failed Operations - Tracks permission denials
5. Server Connection Failures - Health monitoring
6. Tool Usage Analytics - Usage patterns
7. Unusual After-Hours Activity - Temporal anomalies
8. Data Exfiltration Indicators - Read-then-upload patterns
9. API Rate Limiting - Quota tracking
10. Permission Denied Events - Access control auditing


================================================================================
USE CASES
================================================================================

Security Monitoring
-------------------

Detect Data Exfiltration:
index=mcp sourcetype=mcp:jsonrpc mcp.method="tools/call" mcp.tool_name="read_file"
| search mcp.file_path IN ("/etc/shadow", "/etc/passwd", "*.key", "*.pem", "*secret*")
| stats count by mcp.file_path, mcp.client_name
| where count > 5

Monitor GitHub Activity:
index=mcp sourcetype=mcp:jsonrpc mcp.github_action="push_files"
| eval file_content_length=len('params.arguments.files{}.content')
| where file_content_length > 10000
| table _time, mcp.github_owner, mcp.github_repo, file_content_length

Operations Monitoring
---------------------

MCP Server Health:
index=mcp sourcetype=claude:mcp:debug "Connection failed"
| stats count by mcp_server_name
| sort - count

Tool Usage Analytics:
index=mcp sourcetype=mcp:jsonrpc mcp.message_type="request"
| stats count by mcp.tool_name
| sort - count

================================================================================
CIM COMPLIANCE
================================================================================

This TA provides mappings to the Web data model (CIM 5.3):

| tstats count FROM datamodel=Web BY Web.url, Web.status, Web.dest

Mapped Fields:
- action → allowed/blocked based on error presence
- http_method → POST
- url → method (e.g., tools/call)
- status → success/failure
- src → client name
- dest → server name
- vendor_product → "Anthropic MCP"

================================================================================
TROUBLESHOOTING
================================================================================

No Data Appearing
-----------------

1. Check log file creation:
   # Linux/Mac
   ls -l /var/log/mcp/
   cat /var/log/mcp/filesystem.json

   # Windows
   dir C:\ProgramData\mcp\logs\
   type C:\ProgramData\mcp\logs\filesystem.json

2. Verify Splunk is monitoring:
   | rest /services/admin/inputstatus/TailingProcessor:FileStatus
   | search file_path="*mcp*"

3. Check for parsing errors:
   index=_internal source=*splunkd.log* ERROR "mcp:jsonrpc"

Field Extractions Not Working
------------------------------

1. Verify sourcetype:
   index=mcp | stats count by sourcetype

2. Test field extraction:
   index=mcp sourcetype=mcp:jsonrpc
   | head 10
   | table jsonrpc, id, method, result.content{}.text

3. Check JSON validity:
   index=mcp sourcetype=mcp:jsonrpc
   | regex _raw="^\{.+\}$"
   | stats count

================================================================================
REQUIREMENTS
================================================================================

- Splunk: Enterprise 9.x or Universal Forwarder
- MCP Servers: Any compliant server (Node.js, Python, Go, etc.)
- OS: Linux, macOS, Windows

No MCP server modifications required!

================================================================================
SUPPORT
================================================================================

Documentation:
- README.md - Complete technical documentation

Additional Resources:
- MCP Protocol: https://modelcontextprotocol.io/
- Claude Code: https://code.claude.com/docs/
- Splunk Development: https://dev.splunk.com/

Community:
- GitHub Issues: Report issues
- Splunk Answers: Tag with 'mcp' and 'ta-mcp-jsonrpc'

================================================================================
VERSION HISTORY
================================================================================

0.1.2 (2025-01-16)
- Changed CIM mapping from Application State (deprecated) to Web data model
- Added eventtypes.conf and tags.conf for Web data model tagging
- Fixed sample_data.json format (valid JSON array)
- Fixed app.conf is_configured setting

0.1.1 (2025-12-15)
- Initial beta release
- Tested with real MCP server data (232 events)
- 10+ security detections validated
- Support for mcp:jsonrpc and claude:mcp:debug sourcetypes
- 40+ field extractions
- 10 pre-built security searches
- AppInspect compliant

================================================================================
LICENSE
================================================================================

MIT License - See LICENSE file for details

================================================================================
CREDITS
================================================================================

Developed for monitoring Model Context Protocol (MCP) servers in enterprise
environments.

MCP is developed by Anthropic.
Technology Add-on by Rod Soto.

Tested and validated with real attack scenarios. Ready for production deployment.
