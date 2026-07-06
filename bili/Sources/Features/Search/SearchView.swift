import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var libraryStore: LibraryStore
    let showsBottomControls: Bool
    @StateObject private var holder = SearchViewModelHolder()
    @State private var showsAllHotSearches = false

    init(showsBottomControls: Bool = true) {
        self.showsBottomControls = showsBottomControls
    }

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                SearchContentView(
                    viewModel: viewModel,
                    showsHotSearches: libraryStore.showsHotSearches,
                    showsBottomControls: showsBottomControls,
                    showsAllHotSearches: $showsAllHotSearches
                )
            } else {
                SearchLoadingList()
                    .task {
                        holder.configure(api: dependencies.api)
                    }
            }
        }
        .rootNavigationTitle("搜索")
        .nativeTopNavigationChrome()
    }
}
