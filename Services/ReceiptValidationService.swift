// ReceiptValidationService.swift
import Foundation

protocol ReceiptValidationService {
    func validateReceipt(_ data: Data, completion: @escaping (Result<Subscription, Error>) -> Void)
}
