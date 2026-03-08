# TA-Ollama v0.1.4 Release Summary

## Release Information
- **Version**: 0.1.4
- **Release Date**: 2025-11-20
- **CIM Compliance**: CIM 5.0+ Web Datamodel

## Key Improvements

Fixed Splunk AWS compatibility issue 
- Fixed AWS Splunk compatibility issue with `ollama_static_cim_fields` transform validation error
- Migrated static CIM field assignments from transforms.conf to EVAL statements in props.conf for better cross-platform compatibility
- Should not affect any non AWS Splunk installs. 




