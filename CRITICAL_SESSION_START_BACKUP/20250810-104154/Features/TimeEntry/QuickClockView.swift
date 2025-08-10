import SwiftUI

struct QuickClockView: View {
    @EnvironmentObject private var viewModel: ProjectViewModel
    @State private var isRunning: Bool = false
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            timerDisplay
            controls
        }
        .padding()
        .onAppear { startTimerIfNeeded() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Subviews

    private var timerDisplay: some View {
        VStack {
            Text("Quick Clock")
                .font(.headline)
            Text(formattedElapsed)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .padding(.vertical)
        }
    }

    private var controls: some View {
        HStack(spacing: 32) {
            Button(action: toggleRunning) {
                Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }

            Button(action: recordEntry) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
            }
        }
    }

    // MARK: - Actions

    private func toggleRunning() {
        isRunning.toggle()
        if isRunning {
            startTimer()
        } else {
            stopTimer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startTimerIfNeeded() {
        if isRunning { startTimer() }
    }

    private func recordEntry() {
        // TODO: wire this up to your ProjectViewModel logging API
        // e.g. viewModel.addWorkHour(...)
        elapsed = 0
        isRunning = false
        stopTimer()
    }

    // MARK: - Formatting

    private var formattedElapsed: String {
        let hrs = Int(elapsed) / 3600
        let mins = (Int(elapsed) % 3600) / 60
        let secs = Int(elapsed) % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }
}

struct QuickClockView_Previews: PreviewProvider {
    static var previews: some View {
        QuickClockView()
            .environmentObject(ProjectViewModel())
    }
}
