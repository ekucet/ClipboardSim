import SwiftUI
import AppKit

struct SimulatorBar: View {
    @Environment(SimulatorManager.self) private var sm
    @Environment(ClipboardManager.self) private var cm

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

                SyncChip(label: "← Mac", tint: .orange, tip: "Pull Simulator clipboard to Mac") {
                    Task {
                        if let t = await sm.pullFromSim() { cm.copyToMac(t) }
                    }
                }
                .disabled(sm.selectedID.isEmpty)

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
