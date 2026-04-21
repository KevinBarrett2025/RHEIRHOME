// Tab.swift
// RHEIR
//
// Created by Kevin Barrett on 5/22/25.
//

import Foundation

/// Shared tab identifier for the entire app
public enum Tab: CaseIterable, Hashable {
    case projects, receipts, tasks, labor, company
}

public struct AppReleaseProfile: Equatable {
    public enum Mode: String {
        case fastShipV1 = "fast_ship_v1"
        case legacy = "legacy"
    }

    public static let environmentKey = "RHEIR_RELEASE_PROFILE"
    public static let current = AppReleaseProfile()

    public let mode: Mode

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let rawValue = environment[Self.environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch rawValue {
        case Mode.legacy.rawValue, "0", "false", "off", "full":
            self.mode = .legacy
        default:
            self.mode = .fastShipV1
        }
    }

    public var isFastShipV1: Bool {
        mode == .fastShipV1
    }

    public var mainTabs: [Tab] {
        isFastShipV1 ? [.projects, .receipts, .labor, .tasks] : Tab.allCases
    }

    public var shouldHideCompanySurface: Bool {
        isFastShipV1
    }

    public var shouldHideCollaborationSurface: Bool {
        isFastShipV1
    }

    public var shouldUseStreamlinedSessionRouting: Bool {
        isFastShipV1
    }

    public var shouldHideAdvancedBudgetSurfaces: Bool {
        isFastShipV1
    }

    public var shouldHideLegacyAIKeySettings: Bool {
        isFastShipV1
    }

    public var shouldHideSubscriptionManagement: Bool {
        isFastShipV1
    }
}
