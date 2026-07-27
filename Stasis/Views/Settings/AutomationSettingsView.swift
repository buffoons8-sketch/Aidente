import AppKit
import Defaults
import SwiftUI

struct AutomationSettingsView: View {
    @Default(.appLanguage) private var appLanguage

    @State private var scheduleStore = ScheduleStore.shared
    @State private var showingNewTask = false

    var body: some View {
        IadenteSettingsPage {
            IadenteCard(
                "计划任务",
                subtitle: "按设定时间自动调整上限、补电、校准、暂停或放电。错过的任务可在 Mac 唤醒后补做。",
                icon: "calendar.badge.clock",
                colors: IadenteTheme.automationColors
            ) {
                if scheduleStore.tasks.isEmpty {
                    IadenteInsetPanel {
                        HStack(spacing: 13) {
                            IadenteIconBadge(
                                icon: "calendar.badge.plus",
                                colors: IadenteTheme.automationColors,
                                size: 44
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(IadenteL10n.t("还没有计划任务"))
                                    .font(.headline)
                                Text(IadenteL10n.t("创建一项任务，让 iadente 在合适的时间自动照顾电池。"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                } else {
                    ForEach(Array(scheduleStore.tasks.enumerated()), id: \.element.id) {
                        index, task in
                        HStack(spacing: 12) {
                            IadenteIconBadge(
                                icon: task.action.icon,
                                colors: task.action.colors,
                                size: 34
                            )

                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { task.isActive },
                                    set: { scheduleStore.setActive($0, for: task) }
                                )
                            )
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(task.action.colors.first ?? IadenteTheme.jade)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.summary)
                                    .font(.headline)
                                Text(
                                    "\(task.nextRun.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).month().day().hour().minute())) · \(task.repeatRule.title)"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                scheduleStore.remove(task)
                            } label: {
                                Image(systemName: "trash.fill")
                                    .foregroundStyle(IadenteTheme.coral)
                            }
                            .buttonStyle(.borderless)
                            .help(IadenteL10n.t("删除任务"))
                        }
                        .padding(.vertical, 3)

                        if index < scheduleStore.tasks.count - 1 {
                            IadenteRowDivider()
                        }
                    }
                }

                Button {
                    showingNewTask = true
                } label: {
                    Label(IadenteL10n.t("添加计划任务"), systemImage: "plus.circle.fill")
                }
                .buttonStyle(IadenteActionButtonStyle(colors: IadenteTheme.automationColors))
            }

            IadenteCard(
                "Apple 快捷指令",
                subtitle: "在“快捷指令”中使用“打开 URL”操作，即可控制 iadente。",
                icon: "wand.and.stars.inverse",
                colors: IadenteTheme.dashboardColors
            ) {
                IadenteInsetPanel {
                    Text(
                        """
                        iadente://set-limit?value=80
                        iadente://top-up
                        iadente://calibrate
                        iadente://pause
                        iadente://discharge?value=70
                        iadente://resume
                        """
                    )
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .sheet(isPresented: $showingNewTask) {
            NewScheduleTaskView(isPresented: $showingNewTask)
        }
    }
}

private struct NewScheduleTaskView: View {
    @Binding var isPresented: Bool

    @State private var action: ScheduleActionKind = .setChargeLimit
    @State private var value = 80
    @State private var repeatRule: ScheduleRepeatRule = .never
    @State private var nextRun = Date().addingTimeInterval(3_600)
    @State private var runAtNextOpportunity = true

    var body: some View {
        ZStack {
            IadenteSettingsBackground()

            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    IadenteIconBadge(
                        icon: "calendar.badge.plus",
                        colors: IadenteTheme.automationColors,
                        size: 44
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(IadenteL10n.t("添加计划任务"))
                            .font(.title2.bold())
                        Text(IadenteL10n.t("选择动作、执行时间和重复规则"))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                IadenteCard(
                    "任务设置",
                    icon: "slider.horizontal.3",
                    colors: IadenteTheme.automationColors
                ) {
                    IadenteControlRow(
                        "执行动作",
                        icon: action.icon,
                        colors: action.colors
                    ) {
                        Picker("", selection: $action) {
                            ForEach(ScheduleActionKind.allCases) { action in
                                Text(action.title).tag(action)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }

                    if action.usesValue {
                        IadenteRowDivider()
                        IadenteControlRow(
                            IadenteL10n.t(
                                action == .setChargeLimit ? "充电上限" : "放电目标"
                            ),
                            icon: "percent",
                            colors: IadenteTheme.chargingColors
                        ) {
                            HStack {
                                Slider(
                                    value: Binding(
                                        get: { Double(value) },
                                        set: { value = Int($0) }
                                    ),
                                    in: 20...100,
                                    step: 5
                                )
                                .frame(width: 150)
                                Text("\(value)%")
                                    .monospacedDigit()
                                    .frame(width: 42, alignment: .trailing)
                            }
                        }
                    }

                    IadenteRowDivider()
                    IadenteControlRow(
                        "首次执行",
                        icon: "clock.badge.fill",
                        colors: IadenteTheme.generalColors
                    ) {
                        DatePicker(
                            "",
                            selection: $nextRun
                        )
                        .labelsHidden()
                    }

                    IadenteRowDivider()
                    IadenteControlRow(
                        "重复",
                        icon: "repeat.circle.fill",
                        colors: IadenteTheme.dashboardColors
                    ) {
                        Picker("", selection: $repeatRule) {
                            ForEach(ScheduleRepeatRule.allCases) { rule in
                                Text(rule.title).tag(rule)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }

                    IadenteRowDivider()
                    IadenteSettingToggle(
                        "错过后尽快补做",
                        subtitle: "Mac 唤醒并运行 iadente 后执行",
                        icon: "arrow.clockwise.circle.fill",
                        colors: IadenteTheme.automationColors,
                        isOn: $runAtNextOpportunity
                    )
                }

                HStack {
                    Button(IadenteL10n.t("取消")) {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button {
                        ScheduleStore.shared.add(
                            ScheduleTask(
                                action: action,
                                value: value,
                                repeatRule: repeatRule,
                                nextRun: nextRun,
                                isActive: true,
                                runAtNextOpportunity: runAtNextOpportunity
                            )
                        )
                        isPresented = false
                    } label: {
                        Label(IadenteL10n.t("添加任务"), systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(IadenteActionButtonStyle(colors: IadenteTheme.automationColors))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .frame(width: 560, height: 590)
    }
}

private extension ScheduleActionKind {
    var icon: String {
        switch self {
        case .setChargeLimit: "battery.75percent"
        case .startCalibration: "arrow.triangle.2.circlepath.circle.fill"
        case .topUp: "bolt.circle.fill"
        case .pauseCharging: "pause.circle.fill"
        case .dischargeTo: "arrow.down.circle.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .setChargeLimit: IadenteTheme.chargingColors
        case .startCalibration: IadenteTheme.dashboardColors
        case .topUp: IadenteTheme.automationColors
        case .pauseCharging: [IadenteTheme.coral, IadenteTheme.amber]
        case .dischargeTo: IadenteTheme.generalColors
        }
    }
}
