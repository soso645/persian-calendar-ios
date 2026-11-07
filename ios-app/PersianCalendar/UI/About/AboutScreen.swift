import SwiftUI

/// Version, licensing and provenance.
struct AboutScreen: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 48))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(Color.accentColor)
                    Text("Persian Calendar")
                        .font(.title2.bold())
                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("About") {
                Text(
                    "An iOS port of the open-source Android Persian Calendar. "
                        + "Calendar conversion, events and prayer time calculations are ported "
                        + "from the original project's libraries.")
                    .font(.callout)
            }

            Section("License") {
                Text(
                    "This app is released under the GNU General Public License v3, inherited "
                        + "from the Android original.")
                    .font(.callout)
                Link(
                    "Android Persian Calendar",
                    destination: URL(string: "https://github.com/persian-calendar/persian-calendar")!)
            }

            Section("Third-party") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Astronomy Engine").font(.subheadline.weight(.semibold))
                    Text("© Don Cross — MIT license. Vendored at v2.1.19.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Events data").font(.subheadline.weight(.semibold))
                    Text("persian-calendar/events, compiled from official government sources.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionText: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return "Version \(version ?? "—") (\(build ?? "—"))"
    }
}
