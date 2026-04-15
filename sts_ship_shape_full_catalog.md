# RHEIR Ship Shape Full Catalog

## Repo-Local STS Artifacts
- `00_READ_FIRST_MAIN_AUTHORITY.md`
- `10_GM_TESTING_GROUNDS_RUNBOOK.md`
- `20_GM_TO_MAIN_PROMOTION_RUNBOOK.md`
- `SHIP_READINESS_CHECKLIST.md`
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
- `Company/project UI` structured logging
- `Settings support UI` structured logging
- `Hidden debug UI` structured logging
- `Legacy organization knowledge/onboarding/model` structured logging
- `Budget/import helper` structured logging
- `Filters/validation helper` structured logging
- `Organization migration service` structured logging
- `Complete reset service` structured logging
- `CloudKit auth organization create/fetch/delete helper` structured logging
- `CloudKit auth organization invite/zone/join/assignment helper` structured logging
- `CloudKit auth core service` structured logging
- `OrganizationZoneService` structured logging
- `ScalableCloudKitArchitecture` structured logging
- `CloudKitVendorService` structured logging
- `CloudKitOrganizationSharingService` structured logging
- `CloudKitOrganizationDebugService` structured logging
- `AppleIDAuthService` structured logging
- `SimpleCloudKitSharingService` structured logging
- `ProjectDataMigrationService` structured logging
- `CloudKitPaymentMethodService` structured logging
- `DataMigrationService` structured logging
- `JWTService` structured logging
- `PaymentMethodManagementService` structured logging
- `ReceiptOCRService` structured logging
- `Core/UserService` structured logging
- `Core/CloudKitService` structured logging
- `Core/AuthenticationService` structured logging
- `CloudKitSharingService` structured logging
- `TeamMemberService` structured logging
- `EnhancedReceiptService` structured logging
- `VendorManagementService` structured logging
- `OrganizationService` structured logging
- `CloudKitPhotoService` structured logging
- `ProductionChatGPTService` structured logging
- `CloudKitAuthService+User` structured logging
- `EnhancedOrganizationService` structured logging
- `GlobalChatGPTService` structured logging
- `ContextAwareReceiptService` structured logging
- `ReceiptScannerView` structured logging
- `EditProjectView` structured logging
- `LogHoursView` structured logging
- `NewProjectView` structured logging
- `ProjectDetailview` structured logging
- `VendorKnowledgeService` structured logging
- `PaymentMethodKnowledgeService` structured logging
- `OrganizationService` structured logging
- `DeepLinkRouter` structured logging
- `Organization setup/selection` structured logging
- `SignInWithAppleCoordinator` structured logging

## Current Validation Baseline
- Simulator build path: `mcp__xcodebuildmcp__build_sim` with `extraArgs=["-derivedDataPath","/tmp/rheir_gateA_phase1ay_mcp_dd"]`
- Focused parity path: `mcp__xcodebuildmcp__test_sim` with `extraArgs=["-derivedDataPath","/tmp/rheir_parity_phase1ay_mcp_dd","-only-testing:RHEIRTests"]`
- Latest focused parity count: `27/27`

## Known Residual Risks
- Remaining raw `print(...)` statements still exist in `Shared/Features/TimeEntry/AddTeamMemberView.swift`, `Shared/Features/Receipts/ScannedReceiptEntryView.swift`, `Shared/Views/Components/UniversalHeaderView.swift`, and other non-hardened seams.
- `ProjectViewModel` is still oversized even after the extracted stores, though organization/project synchronization is now isolated behind `OrganizationProjectSyncStore`.
- `CompanyStore` now lives in the compiled state layer rather than the settings view, but the broader company/project coordination flow still spans multiple UI files.
- Direct CLI `xcodebuild` evidence remains less stable than the MCP simulator path in the local CoreSimulator environment.
- Device signing is still unresolved for physical-device gate execution.
