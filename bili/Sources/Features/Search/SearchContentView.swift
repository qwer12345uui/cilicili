import SwiftUI

struct SearchContentView: View {
    @ObservedObject var viewModel: SearchViewModel
    let showsHotSearches: Bool
    let showsBottomControls: Bool
    @Binding var showsAllHotSearches: Bool
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        SearchListView(
            viewModel: viewModel,
            showsHotSearches: showsHotSearches,
            showsAllHotSearches: $showsAllHotSearches
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsBottomSearchControls {
                SearchBottomControls(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.2), value: showsBottomSearchControls)
        .searchable(
            text: Binding(
                get: { viewModel.query },
                set: { query in
                    viewModel.query = query
                    viewModel.queryChanged()
                }
            ),
            placement: .automatic,
            prompt: viewModel.searchPrompt
        )
        .searchFocused($isSearchFocused)
        .searchSuggestions {
            ForEach(viewModel.suggestions) { item in
                Label(item.value, systemImage: "magnifyingglass")
                    .searchCompletion(item.value)
            }
        }
        .onSubmit(of: .search) {
            Task { await viewModel.search() }
        }
        .overlay {
            if case .failed(let message) = viewModel.state, viewModel.results.isEmpty {
                ErrorStateView(title: "搜索失败", message: message) {
                    Task { await viewModel.search() }
                }
            }
        }
        .task {
            await loadHotSearchIfNeeded()
        }
        .toolbar {
            if showsKeyboardSearchControls {
                ToolbarItem(placement: .keyboard) {
                    SearchBottomControls(viewModel: viewModel)
                }
            }
        }
    }

    private var showsBottomSearchControls: Bool {
        showsBottomControls && !isSearchFocused
    }

    private var showsKeyboardSearchControls: Bool {
        showsBottomControls && isSearchFocused
    }

    private func loadHotSearchIfNeeded() async {
        guard showsHotSearches else { return }
        await viewModel.loadHotSearch()
    }
}

private struct SearchBottomControls: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        HStack(spacing: 8) {
            BiliGlassSegmentedControl(
                options: Array(SearchScope.allCases),
                selected: viewModel.selectedScope,
                title: { $0.title }
            ) { scope in
                Task {
                    await viewModel.selectScope(scope, animation: .smooth(duration: 0.28))
                }
            }
            .frame(maxWidth: .infinity)

            SearchSortHeaderButton(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityLabel("搜索类型和排序")
    }
}
