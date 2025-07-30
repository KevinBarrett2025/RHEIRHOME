import SwiftUI

struct ReceiptRowView: View {
    let receipt: Receipt
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(receipt.vendor)
                        .font(.headline)
                    
                    if receipt.isReturn {
                        Text("RETURN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Text(receipt.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !receipt.notes.isEmpty {
                    Text(receipt.notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Label(receipt.category.rawValue, systemImage: "tag.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !receipt.paymentMethod.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(receipt.paymentMethod)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if receipt.hasPhotos {
                        Image(systemName: "photo.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text((receipt.isReturn ? -receipt.amount : receipt.amount).formatAsCurrency())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(receipt.isReturn ? .red : .primary)
                
                if receipt.taxAmount > 0 {
                    Text("Tax: \(receipt.taxAmount.formatAsCurrency())")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReceiptRowView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleReceipt = Receipt(
            vendor: "Home Depot",
            date: Date(),
            amount: 156.78,
            notes: "Lumber for framing",
            category: .material,
            paymentMethod: "Chase Visa"
        )
        
        ReceiptRowView(receipt: sampleReceipt)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}