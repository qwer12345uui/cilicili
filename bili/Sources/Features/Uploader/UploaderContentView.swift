import SwiftUI

struct UploaderContentView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    let owner: VideoOwner
    @ObservedObject var viewModel: UploaderViewModel

    @State private var contentWidth: CGFloat = 0
    @State private var selectedSection: UploaderProfileSection

    init(owner: VideoOwner, viewModel: UploaderViewModel) {
        self.owner = owner
        self.viewModel = viewModel
        _selectedSection = State(initialValue: Self.initialSection)
    }

    var body: some View {
        ScrollView {
            UploaderContentWidthReader()

            VStack(alignment: .leading, spacing: 18) {
                UploaderHeaderView(owner: owner, viewModel: viewModel)

                Picker("内容", selection: $selectedSection) {
                    ForEach(UploaderProfileSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 12)

                selectedContent
            }
            .padding(.vertical, 12)
        }
        .onPreferenceChange(UploaderContentWidthPreferenceKey.self, perform: updateContentWidth)
        .refreshable {
            await refreshSelectedSection()
        }
        .task {
            await viewModel.loadInitial()
        }
        .task(id: selectedSection) {
            switch selectedSection {
            case .videos:
                break
            case .dynamics:
                await viewModel.loadDynamicsIfNeeded()
            case .collections:
                await viewModel.loadSeasonSeriesIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .videos:
            UploaderVideosSection(
                viewModel: viewModel,
                metrics: HomeFeedLayoutMetrics(mode: .doubleColumn, containerWidth: contentWidth)
            )
        case .dynamics:
            UploaderDynamicsSection(
                api: dependencies.api,
                viewModel: viewModel,
                contentWidth: contentWidth
            )
        case .collections:
            UploaderSeasonSeriesSection(viewModel: viewModel)
        }
    }

    private func refreshSelectedSection() async {
        switch selectedSection {
        case .videos:
            await viewModel.refresh()
        case .dynamics:
            await viewModel.refreshDynamics()
        case .collections:
            await viewModel.refreshSeasonSeries()
        }
    }

    private func updateContentWidth(_ width: CGFloat) {
        let roundedWidth = width.rounded(.down)
        guard abs(roundedWidth - contentWidth) > 0.5 else { return }
        contentWidth = roundedWidth
    }

    private static var initialSection: UploaderProfileSection {
        guard let value = argumentValue(after: "--start-uploader-section") else { return .videos }
        return UploaderProfileSection(argumentValue: value) ?? .videos
    }

    private static func argumentValue(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        let value = arguments[valueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private enum UploaderProfileSection: String, CaseIterable, Identifiable {
    case videos
    case dynamics
    case collections

    var id: String { rawValue }

    init?(argumentValue: String) {
        switch argumentValue.lowercased() {
        case "video", "videos", "archive", "archives":
            self = .videos
        case "dynamic", "dynamics":
            self = .dynamics
        case "collection", "collections", "season", "seasons", "series":
            self = .collections
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .videos:
            return "投稿"
        case .dynamics:
            return "动态"
        case .collections:
            return "合集"
        }
    }
}
