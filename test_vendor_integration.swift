import Foundation

// Test script to verify vendor and payment method integration
func testVendorIntegration() {
    print("🧪 Testing Vendor and Payment Method Integration")
    
    // Create services
    let vendorService = VendorManagementService(organizationID: "TEST-ORG")
    let paymentService = PaymentMethodManagementService(organizationID: "TEST-ORG")
    
    print("✅ Services initialized successfully")
    
    // Test vendor creation
    let vendor = vendorService.findOrCreateVendor(name: "Home Depot", category: .hardware)
    print("✅ Created vendor: \(vendor.name) - Category: \(vendor.category.rawValue)")
    
    // Test payment method creation
    let paymentMethod = paymentService.findOrCreatePaymentMethod(name: "Chase Visa", type: .creditCard)
    print("✅ Created payment method: \(paymentMethod.displayName)")
    
    // Test spending tracking
    vendorService.updateVendorSpending(vendorID: vendor.id, amount: 156.78)
    paymentService.updatePaymentMethodSpending(paymentMethodID: paymentMethod.id, amount: 156.78)
    print("✅ Updated spending totals")
    
    // Test top vendors
    let topVendors = vendorService.getTopVendors(limit: 5)
    print("✅ Top vendors: \(topVendors.map { $0.name })")
    
    print("🎉 Integration test completed successfully!")
}