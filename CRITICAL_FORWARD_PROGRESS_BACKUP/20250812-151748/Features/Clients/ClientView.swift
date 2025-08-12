import SwiftUI

struct ClientView: View {
  @EnvironmentObject var viewModel: ProjectViewModel

  var body: some View {
    VStack {
      Text("Client Dashboard")
        .font(.headline)
      // you can show client-specific info here, once you add it to the VM
      Spacer()
    }
    .padding()
  }
}

#if DEBUG
struct ClientView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      ClientView()
        .environmentObject(ProjectViewModel())
    }
    .previewDevice("iPhone 14 Pro")
    .previewDisplayName("Client Dashboard")
  }
}
#endif
