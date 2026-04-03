import SwiftUI
import AppKit

struct SimulatorBar: View {
    @Environment(SimulatorManager.self) private var sm
    @Environment(ClipboardManager.self) private var cm

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "iphone")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                if sm.noSimulatorRunning {
                    Text("No booted simulator")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                } else {
                    @Bindable var b = sm
                    Picker("", selection: $b.selectedID) {
                        ForEach(sm.devices) { d in
                            Text(d.name).tag(d.id)
                        }
                    }
                    .labelsHidden()
                    .font(.system(size: 12))
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
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
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Refresh Simulators")
            }
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 9)
    }
}
