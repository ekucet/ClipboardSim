import SwiftUI
import AppKit

struct SimulatorBar: View {
    @Environment(SimulatorManager.self) private var sm
    @Environment(ClipboardManager.self) private var cm

    private enum PullFeedback { case idle, pulled, empty, error }
    @State private var pullFeedback: PullFeedback = .idle
    @State private var isPulling = false

    private var pullLabel: String {
        switch pullFeedback {
        case .idle:   return "← Mac"
        case .pulled: return "✓ Mac"
        case .empty:  return "Boş"
        case .error:  return "Hata"
        }
    }

    private var pullTint: Color {
        switch pullFeedback {
        case .idle:   return .orange
        case .pulled: return .green
        case .empty:  return .secondary
        case .error:  return .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: sm.noSimulatorRunning ? "iphone.slash" : "iphone")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(sm.noSimulatorRunning ? .quaternary : .secondary)
                    .frame(width: 16)

                if sm.noSimulatorRunning {
                    Text("No booted simulator")
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                } else {
                    @Bindable var b = sm
                    Picker("", selection: $b.selectedID) {
                        ForEach(sm.devices) { d in
                            Text(d.name).tag(d.id)
                        }
                    }
                    .labelsHidden()
                    .font(.system(size: 11))
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                SyncChip(label: "→ Sim", tint: .green, tip: "Send Mac clipboard to Simulator") {
                    let t = NSPasteboard.general.string(forType: .string) ?? ""
                    guard !t.isEmpty else { return }
                    sm.pushToSim(t)
                }
                .disabled(sm.selectedID.isEmpty)

                SyncChip(label: pullLabel, tint: pullTint, tip: "Pull Simulator clipboard to Mac") {
                    guard !isPulling else { return }
                    isPulling = true
                    Task {
                        let result = await sm.pullFromSim()
                        switch result {
                        case .ok(let t):
                            cm.copyToMac(t)
                            withAnimation { pullFeedback = .pulled }
                        case .empty:
                            withAnimation { pullFeedback = .empty }
                        case .error:
                            withAnimation { pullFeedback = .error }
                        }
                        isPulling = false
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation { pullFeedback = .idle }
                    }
                }
                .disabled(sm.selectedID.isEmpty || isPulling)

                Button { sm.refresh() } label: {
                    ZStack {
                        if sm.isRefreshing {
                            ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Refresh Simulators")
            }
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }
}
