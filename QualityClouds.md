Every time you are asked to create or modify Salesforce elements in this repository (Apex classes, LWC components, Triggers, Flows, permission sets, metadata, etc.), follow this exact workflow:

Fetch rules first: Before generating or modifying any element, call mcp__QualityCloudsMCPServer_f14f__sf_get_rules for the relevant element type (e.g. ApexClass, Flow, LightningComponentBundle). Use the returned rules as guidelines — code must be written to comply with them from the start.

Analyze after generating: After generating or modifying any element, call mcp__QualityCloudsMCPServer_f14f__sf_analyze_element to analyze it.

Fix newly generated code immediately: Any issues found in code you just wrote or modified must be fixed before returning the result to the user.

Highlight existing code issues: Issues found in pre-existing code that was not part of the current change must be reported clearly to the user, but not modified unless explicitly asked.

Only return compliant code: Do not present the final code or confirm the task as complete until the newly generated or modified elements pass QualityClouds analysis without errors.

Request a write-off when a fix isn't viable: If an issue (new or pre-existing) cannot be fixed — because it is a policy/organisational rule, a false positive, or fixing it would require changes out of scope or unsafe — do not call mcp__QualityCloudsMCPServer_f14f__sf_request_writeoff on your own initiative. First explain the issue and why you believe a fix isn't viable, and ask the user to confirm/validate that a write-off should be requested. Only call sf_request_writeoff after the user gives that confirmation. This submits the issue for a validator to review and accept or reject the write-off request. Always inform the user once the write-off has been requested.

This applies to all Salesforce element types including but not limited to: Apex classes and triggers, Lightning Web Components (HTML, JS, CSS, metadata), Visualforce pages and components, permission sets and profiles, custom metadata and custom objects, Flows and process builders.