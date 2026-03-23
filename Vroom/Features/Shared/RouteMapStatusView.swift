import SwiftUI

struct RouteMapStatusView: View {
    let title: String
    let subtitle: String
    let icon: String
    var tone: RoadStateTone = .info
    var showsProgress = false

    var body: some View {
        RoadPanel {
            VStack(alignment: .center, spacing: RoadSpacing.compact) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tone.tint)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: RoadRadius.medium, style: .continuous)
                            .fill(tone.fill)
                    )

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RoadTheme.textPrimary)

                Text(subtitle)
                    .font(RoadTypography.supporting)
                    .foregroundStyle(RoadTheme.textSecondary)
                    .multilineTextAlignment(.center)

                if showsProgress {
                    ProgressView()
                        .tint(RoadTheme.primaryAction)
                        .padding(.top, RoadSpacing.small)
                }
            }
            .padding(RoadSpacing.regular)
        }
    }
}
