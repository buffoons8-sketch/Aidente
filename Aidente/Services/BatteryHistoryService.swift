import Foundation
import Observation
import os.log

struct BatteryCapacitySample: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let batteryPercentage: Int
    let currentCapacityMilliampHours: Int
    let estimatedFullChargeCapacityMilliampHours: Int
    let designCapacityMilliampHours: Int
    let batteryHealth: Double
    let isCharging: Bool
}

private enum BatteryHistoryStore {
    struct Archive: Codable, Sendable {
        let version: Int
        let trackingStartedAt: Date
        let samples: [BatteryCapacitySample]
    }

    static var fileURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Aidente", isDirectory: true)
            .appendingPathComponent("battery-capacity-history.json")
    }

    static var installationDate: Date {
        let creationDate = try? Bundle.main.bundleURL.resourceValues(
            forKeys: [.creationDateKey]
        ).creationDate
        return min(creationDate ?? Date(), Date())
    }

    static func load() throws -> Archive? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        if let archive = try? decoder.decode(Archive.self, from: data) {
            return archive
        }

        // 0.7.0 stored a flat, high-frequency array. Preserve it while
        // migrating to the once-per-day archive introduced in 0.8.0.
        let legacySamples = try decoder.decode([BatteryCapacitySample].self, from: data)
        return Archive(
            version: 1,
            trackingStartedAt: min(
                legacySamples.first?.timestamp ?? installationDate,
                installationDate
            ),
            samples: legacySamples
        )
    }

    static func save(_ archive: Archive) throws {
        let url = fileURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(archive)
        try data.write(to: url, options: .atomic)
    }
}

@MainActor
@Observable
final class BatteryHistoryService {
    private static let archiveVersion = 2

    private let batteryService: BatteryService
    private let logger = Logger(
        subsystem: "com.aidente.app",
        category: "BatteryHistory"
    )

    private var metricsObservation: Task<Void, Never>?
    private var dayChangeObserver: NSObjectProtocol?
    private var loadTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var hasLoadedHistory = false

    private(set) var samples: [BatteryCapacitySample] = []
    private(set) var trackingStartedAt = BatteryHistoryStore.installationDate

    init(batteryService: BatteryService) {
        self.batteryService = batteryService
        if AidenteRuntime.isUIPreview {
            hasLoadedHistory = true
            trackingStartedAt = Calendar.current.date(
                byAdding: .day,
                value: -179,
                to: Calendar.current.startOfDay(for: Date())
            ) ?? Date()
        } else {
            loadHistory()
        }
        startObservingMetrics()
        startObservingDayChanges()
    }

    func captureCurrent(force: Bool = false) {
        let metrics = batteryService.metrics
        guard metrics.designCapacityMilliampHours > 0,
              metrics.estimatedFullChargeCapacityMilliampHours > 0 else {
            return
        }

        if AidenteRuntime.isUIPreview {
            if samples.isEmpty {
                samples = makePreviewSamples(from: metrics)
            }
            return
        }

        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        if !force, let last = samples.last,
           calendar.isDate(last.timestamp, inSameDayAs: now) {
            return
        }

        let sample = BatteryCapacitySample(
            id: UUID(),
            timestamp: now,
            batteryPercentage: metrics.batteryPercentage,
            currentCapacityMilliampHours: metrics.currentCapacityMilliampHours,
            estimatedFullChargeCapacityMilliampHours:
                metrics.estimatedFullChargeCapacityMilliampHours,
            designCapacityMilliampHours: metrics.designCapacityMilliampHours,
            batteryHealth: metrics.batteryHealth,
            isCharging: metrics.isCharging
        )
        samples.append(sample)
        normalizeDailyHistory()
        scheduleSaveIfReady()

        logger.debug(
            "Capacity sample recorded: current=\(sample.currentCapacityMilliampHours)mAh full=\(sample.estimatedFullChargeCapacityMilliampHours)mAh design=\(sample.designCapacityMilliampHours)mAh health=\(sample.batteryHealth)%"
        )
    }

    func stop() {
        metricsObservation?.cancel()
        metricsObservation = nil
        if let dayChangeObserver {
            NotificationCenter.default.removeObserver(dayChangeObserver)
            self.dayChangeObserver = nil
        }
        loadTask?.cancel()
        loadTask = nil
        saveTask?.cancel()
        saveTask = nil

        guard hasLoadedHistory, !AidenteRuntime.isUIPreview else { return }
        try? BatteryHistoryStore.save(makeArchive())
    }

    private func loadHistory() {
        loadTask = Task { [weak self] in
            let loaded = await Task.detached(priority: .utility) {
                try? BatteryHistoryStore.load()
            }.value
            guard let self, !Task.isCancelled else { return }

            let pending = self.samples
            var merged = (loaded?.samples ?? []) + pending
            merged.sort { $0.timestamp < $1.timestamp }
            var seen = Set<UUID>()
            merged = merged.filter { seen.insert($0.id).inserted }
            self.samples = merged
            self.trackingStartedAt = loaded?.trackingStartedAt
                ?? merged.first?.timestamp
                ?? BatteryHistoryStore.installationDate
            self.normalizeDailyHistory()
            self.hasLoadedHistory = true
            self.captureCurrent(force: self.samples.isEmpty)
            self.scheduleSaveIfReady()
        }
    }

    private func startObservingMetrics() {
        metricsObservation = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.captureCurrent()
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.batteryService.metrics
                    } onChange: {
                        Task { @MainActor in
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }

    private func startObservingDayChanges() {
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.captureCurrent()
            }
        }
    }

    private func normalizeDailyHistory() {
        let calendar = Calendar.autoupdatingCurrent
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        var latestByDay: [Date: BatteryCapacitySample] = [:]
        for sample in sorted {
            latestByDay[calendar.startOfDay(for: sample.timestamp)] = sample
        }
        samples = latestByDay.values.sorted { $0.timestamp < $1.timestamp }
    }

    private func scheduleSaveIfReady() {
        guard hasLoadedHistory, !AidenteRuntime.isUIPreview else { return }
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled else { return }
            let archive = self.makeArchive()
            let saved = await Task.detached(priority: .utility) {
                do {
                    try BatteryHistoryStore.save(archive)
                    return true
                } catch {
                    return false
                }
            }.value
            if !saved {
                self.logger.error("Could not save battery capacity history")
            }
        }
    }

    private func makePreviewSamples(from metrics: BatteryMetrics) -> [BatteryCapacitySample] {
        let fullCapacity = metrics.estimatedFullChargeCapacityMilliampHours
        let designCapacity = metrics.designCapacityMilliampHours
        let calendar = Calendar.current
        let start = calendar.date(
            byAdding: .day,
            value: -179,
            to: calendar.startOfDay(for: Date())
        ) ?? Date()
        trackingStartedAt = start

        return (0..<180).map { index in
            let isLatest = index == 179
            let percentage = isLatest
                ? metrics.batteryPercentage
                : 45 + ((index * 17) % 38)
            let estimatedFull = isLatest
                ? fullCapacity
                : max(1, fullCapacity + (179 - index) / 9 + ((index % 9) - 4) * 2)
            let currentCapacity = isLatest
                ? metrics.currentCapacityMilliampHours
                : Int((Double(estimatedFull) * Double(percentage) / 100).rounded())
            return BatteryCapacitySample(
                id: UUID(),
                timestamp: calendar.date(byAdding: .day, value: index, to: start)
                    ?? start,
                batteryPercentage: percentage,
                currentCapacityMilliampHours: currentCapacity,
                estimatedFullChargeCapacityMilliampHours: estimatedFull,
                designCapacityMilliampHours: designCapacity,
                batteryHealth: Double(estimatedFull) * 100 / Double(designCapacity),
                isCharging: index % 4 == 0
            )
        }
    }

    private func makeArchive() -> BatteryHistoryStore.Archive {
        BatteryHistoryStore.Archive(
            version: Self.archiveVersion,
            trackingStartedAt: trackingStartedAt,
            samples: samples
        )
    }
}
