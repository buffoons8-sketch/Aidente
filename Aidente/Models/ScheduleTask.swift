import Defaults
import Foundation
import Observation

enum ScheduleActionKind: String, Codable, CaseIterable, Identifiable {
    case setChargeLimit
    case startCalibration
    case topUp
    case pauseCharging
    case dischargeTo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .setChargeLimit: AidenteL10n.t("设置充电上限")
        case .startCalibration: AidenteL10n.t("开始电池校准")
        case .topUp: AidenteL10n.t("临时充至 100%")
        case .pauseCharging: AidenteL10n.t("暂停充电")
        case .dischargeTo: AidenteL10n.t("放电至")
        }
    }

    var usesValue: Bool {
        self == .setChargeLimit || self == .dischargeTo
    }
}

enum ScheduleRepeatRule: String, Codable, CaseIterable, Identifiable {
    case never
    case daily
    case weekdays
    case weekly
    case biweekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: AidenteL10n.t("仅一次")
        case .daily: AidenteL10n.t("每天")
        case .weekdays: AidenteL10n.t("工作日")
        case .weekly: AidenteL10n.t("每周")
        case .biweekly: AidenteL10n.t("每两周")
        case .monthly: AidenteL10n.t("每月")
        }
    }
}

struct ScheduleTask: Codable, Identifiable, Equatable {
    var id = UUID()
    var action: ScheduleActionKind
    var value: Int
    var repeatRule: ScheduleRepeatRule
    var nextRun: Date
    var isActive: Bool
    var runAtNextOpportunity: Bool

    var summary: String {
        if action.usesValue {
            "\(action.title) \(value)%"
        } else {
            action.title
        }
    }
}

@MainActor
@Observable
final class ScheduleStore {
    static let shared = ScheduleStore()

    private(set) var tasks: [ScheduleTask] = []

    private init() {
        load()
    }

    func add(_ task: ScheduleTask) {
        tasks.append(task)
        tasks.sort { $0.nextRun < $1.nextRun }
        save()
    }

    func remove(_ task: ScheduleTask) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func setActive(_ active: Bool, for task: ScheduleTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isActive = active
        save()
    }

    func takeDueTasks(at date: Date = Date()) -> [ScheduleTask] {
        var due: [ScheduleTask] = []
        var advancedTask = false

        for index in tasks.indices where tasks[index].isActive && tasks[index].nextRun <= date {
            let lateness = date.timeIntervalSince(tasks[index].nextRun)
            if lateness <= 600 || tasks[index].runAtNextOpportunity {
                due.append(tasks[index])
            }
            advanceTask(at: index, after: date)
            advancedTask = true
        }

        if advancedTask {
            tasks.sort { $0.nextRun < $1.nextRun }
            save()
        }

        return due
    }

    private func advanceTask(at index: Int, after date: Date) {
        guard tasks.indices.contains(index) else { return }
        let calendar = Calendar.autoupdatingCurrent

        if tasks[index].repeatRule == .never {
            tasks[index].isActive = false
            return
        }

        var next = tasks[index].nextRun
        repeat {
            switch tasks[index].repeatRule {
            case .never:
                tasks[index].isActive = false
            case .daily:
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? date.addingTimeInterval(86_400)
            case .weekdays:
                repeat {
                    next = calendar.date(byAdding: .day, value: 1, to: next)
                        ?? date.addingTimeInterval(86_400)
                } while calendar.isDateInWeekend(next)
            case .weekly:
                next = calendar.date(byAdding: .day, value: 7, to: next)
                    ?? date.addingTimeInterval(604_800)
            case .biweekly:
                next = calendar.date(byAdding: .day, value: 14, to: next)
                    ?? date.addingTimeInterval(1_209_600)
            case .monthly:
                next = calendar.date(byAdding: .month, value: 1, to: next)
                    ?? date.addingTimeInterval(2_592_000)
            }
        } while tasks[index].isActive && next <= date

        tasks[index].nextRun = next
    }

    private func load() {
        let data = Defaults[.scheduleTasksData]
        guard !data.isEmpty,
            let decoded = try? JSONDecoder().decode([ScheduleTask].self, from: data)
        else {
            tasks = []
            return
        }
        tasks = decoded.sorted { $0.nextRun < $1.nextRun }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        Defaults[.scheduleTasksData] = data
    }
}
