import SwiftUI

// MARK: - Semi-Transparent Components for Project Views

struct SemiTransparentTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isRequired: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            TextField(title, text: $text)
                .textFieldStyle(.plain)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SemiTransparentCurrencyField: View {
    let title: String
    @Binding var text: String
    var isRequired: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isRequired {
                    Text("*")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            HStack {
                Text("$")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("0", text: $text)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SemiTransparentDatePicker: View {
    let title: String
    @Binding var selection: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            DatePicker(title, selection: $selection, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}