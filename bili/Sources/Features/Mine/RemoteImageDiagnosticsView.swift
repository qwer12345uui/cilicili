import SwiftUI

struct RemoteImageDiagnosticsView: View {
    @ObservedObject var libraryStore: LibraryStore
    @State private var cacheStatistics: RemoteImageCacheStatistics?
    @State private var cdnStatistics: RemoteImageCDNDiagnosticsSnapshot?
    @State private var isLoading = false

    var body: some View {
        Form {
            cacheSection
            cdnSection
            nodeSection
            degradedNodeSection

            Section {
                Button(role: .destructive) {
                    Task {
                        await resetDiagnostics()
                    }
                } label: {
                    Label("重置诊断数据", systemImage: "arrow.counterclockwise")
                }
                .disabled(isLoading)
            } footer: {
                Text("只统计数量和 CDN 节点名，不记录图片地址、图片内容或账号信息。重置不会清理图片缓存，也不会改变当前节点降级状态。")
            }
        }
        .tint(libraryStore.appTintColor)
        .formStyle(.grouped)
        .nativeTopScrollEdgeEffect()
        .navigationTitle("图片加载诊断")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await reload()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .accessibilityLabel("刷新图片加载诊断")
            }
        }
        .task {
            await reload()
        }
    }

    private var cacheSection: some View {
        Section("缓存") {
            if let cacheStatistics {
                LabeledContent("命中", value: cacheStatistics.hits.formatted())
                LabeledContent("未命中", value: cacheStatistics.misses.formatted())
                LabeledContent("命中率", value: cacheHitRate(cacheStatistics))
                LabeledContent("内存条目", value: cacheStatistics.memoryEntryCount.formatted())
                LabeledContent("正在加载", value: cacheStatistics.inFlightCount.formatted())
                LabeledContent(
                    "磁盘占用",
                    value: "\(ResourceCacheByteFormatter.bytes(cacheStatistics.diskUsage)) / \(ResourceCacheByteFormatter.bytes(cacheStatistics.diskCapacity))"
                )
            } else {
                loadingRow
            }
        }
    }

    private var cdnSection: some View {
        Section("B站图片 CDN") {
            LabeledContent(
                "自动切换实验",
                value: libraryStore.remoteImageCDNFailoverExperimentEnabled ? "已开启" : "未开启"
            )
            if let cdnStatistics {
                LabeledContent("加载任务", value: cdnStatistics.requestCount.formatted())
                LabeledContent("成功响应", value: cdnStatistics.successCount.formatted())
                LabeledContent("瞬时失败", value: cdnStatistics.transientFailureCount.formatted())
                LabeledContent("自动切换", value: cdnStatistics.automaticSwitchCount.formatted())
            } else {
                loadingRow
            }
        }
    }

    private var nodeSection: some View {
        Section("CDN 节点") {
            if let cdnStatistics {
                ForEach(cdnStatistics.hosts) { node in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.host)
                            .font(.body.monospaced())
                        Text("请求 \(node.requestCount) · 成功 \(node.successCount) · 瞬时失败 \(node.transientFailureCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                loadingRow
            }
        }
    }

    private var degradedNodeSection: some View {
        Section("当前降级节点") {
            if let cdnStatistics {
                if cdnStatistics.degradedHosts.isEmpty {
                    Text("无")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cdnStatistics.degradedHosts) { node in
                        LabeledContent(
                            node.host,
                            value: "剩余 \(Int(node.remainingTime.rounded(.up))) 秒"
                        )
                    }
                }
            } else {
                loadingRow
            }
        }
    }

    private var loadingRow: some View {
        HStack {
            Text("读取中")
            Spacer(minLength: 8)
            ProgressView()
                .controlSize(.small)
        }
    }

    private func cacheHitRate(_ statistics: RemoteImageCacheStatistics) -> String {
        let total = statistics.hits + statistics.misses
        guard total > 0 else { return "-" }
        return "\(Int((Double(statistics.hits) / Double(total) * 100).rounded()))%"
    }

    @MainActor
    private func reload() async {
        guard !isLoading else { return }
        isLoading = true
        cacheStatistics = await RemoteImageCache.shared.statistics()
        cdnStatistics = RemoteImageCDNHealthMemory.shared.diagnostics()
        isLoading = false
    }

    @MainActor
    private func resetDiagnostics() async {
        await RemoteImageCache.shared.resetDiagnostics()
        cacheStatistics = nil
        cdnStatistics = nil
        await reload()
    }
}
