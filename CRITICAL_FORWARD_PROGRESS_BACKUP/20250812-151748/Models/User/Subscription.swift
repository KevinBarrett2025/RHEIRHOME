// Subscription.swift
import Foundation

struct Subscription {
    let productID: String
    let expiryDate: Date
    var isActive: Bool { expiryDate > Date() }
}
