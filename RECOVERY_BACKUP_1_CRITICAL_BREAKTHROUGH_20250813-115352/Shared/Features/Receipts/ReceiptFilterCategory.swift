// ReceiptFilterCategory.swift
import Foundation

public enum ReceiptFilterCategory: String, CaseIterable, Hashable {
    case generalConditions
    case materials
    case labor
    case contingency
}