# RHEIR Ship Shape Full Catalog

## Repo-Local STS Artifacts
- `00_READ_FIRST_MAIN_AUTHORITY.md`
- `10_GM_TESTING_GROUNDS_RUNBOOK.md`
- `20_GM_TO_MAIN_PROMOTION_RUNBOOK.md`
- `STS_Rule_of_Law.md`
- `STS_Status.md`
- `sts_master_execution_spine.md`
- `sts_ship_mode_nx_board.md`
- `sts_ship_shape_full_catalog.md`
- `Docs/Recovery/CODEX_THREAD_CONTINUITY.md`

## Active Hardening Seams
- `LocalCacheStore`
- `ProjectStore`
- `ProjectRepository`
- `OrganizationProjectSyncStore`
- `ProjectAccessStore`
- `ReceiptProjectStore`
- `ReceiptIntelligenceStore`
- `LaborStore`
- `CompanyStore`
- `TeamMemberStore`
- `OfflineDataManager` structured logging
- `CloudKitProjectService` structured logging
- `CloudKitZoneManager` structured logging
- `RHEIRCloudKitManager` structured logging
- `VendorKnowledgeService` structured logging
- `PaymentMethodKnowledgeService` structured logging
- `OrganizationService` structured logging
- `DeepLinkRouter` structured logging
- `Organization setup/selection` structured logging
- `SignInWithAppleCoordinator` structured logging

## Current Validation Baseline
- Simulator build path: `mcp__xcodebuildmcp__build_sim` with `extraArgs=["-derivedDataPath","/tmp/rheir_gateA_phase1g_mcp_dd"]`
- Focused parity path: `mcp__xcodebuildmcp__test_sim` with `extraArgs=["-derivedDataPath","/tmp/rheir_parity_phase1g_mcp_dd","-only-testing:RHEIRTests"]`
- Latest focused parity count: `27/27`

## Known Residual Risks
- Remaining raw `print(...)` statements still exist in active production files outside the hardened receipt/project flow.
- `ProjectViewModel` is still oversized even after the extracted stores, though organization/project synchronization is now isolated behind `OrganizationProjectSyncStore`.
- `CompanyStore` now lives in the compiled state layer rather than the settings view, but the broader company/project coordination flow still spans multiple UI files.
- Direct CLI `xcodebuild` evidence remains less stable than the MCP simulator path in the local CoreSimulator environment.
- Device signing is still unresolved for physical-device gate execution.
