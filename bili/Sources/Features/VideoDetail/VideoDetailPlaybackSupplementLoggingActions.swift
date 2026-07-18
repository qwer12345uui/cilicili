import Foundation

extension VideoDetailViewModel {
    func recordSupplementalPlayURLLoadStarted(preferredQuality: Int?) {
        let mode = libraryStore.videoStartupRequestSchedulingExperimentEnabled ? "targetOnly" : "full"
        PlayerMetricsLog.record(
            .qualitySupplement,
            metricsID: detail.bvid,
            title: detail.title,
            message: "start preferred=\(preferredQuality ?? 0) mode=\(mode)"
        )
    }

    func recordSupplementalPlayURLLoadFailed(_ error: Error) {
        PlayerMetricsLog.record(
            .qualitySupplement,
            metricsID: detail.bvid,
            title: detail.title,
            message: "failed \(error.localizedDescription)"
        )
    }
}
