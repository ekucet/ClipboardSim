import SwiftUI

struct SectionHeader<T: View>: View {
    let title: String
    @ViewBuilder var trailing: T

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.quaternary)
                .kerning(0.8)
            Spacer()
            trailing
        }
        .padding(.horizontal, DS.hPad)
        .padding(.top, 10)
        .padding(.bottom, 5)
    }
}
