import AppKit
import Defaults
import SwiftUI

struct AutomationSettingsView: View {
    @Default(.appLanguage) private var appLanguage

    @State private var scheduleStore = ScheduleStore.shared
    @State private var showingNewTask = false

    var body: some View {
        AidenteSettingsPage {
            AidenteCard(
                "计划任务",
                subtitle: "按设定时间自动调整上限、补电、校准、暂停或放电。错过的任务可在 Mac 唤醒后补做。",
                icon: "calendar.badge.clock",
                colors: AidenteTheme.automationColors
            ) {
                if scheduleStore.tasks.isEmpty {
                    AidenteInsetPanel {
                        HStack(spacing: 13) {
                            AidenteIconBadge(
                                icon: "calendar.badge.plus",
                                colors: AidenteTheme.automationColors,
                                size: 44
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(AidenteL10n.t("还没有计划任务"))
                                    .font(.headline)
                                Text(AidenteL10n.t("创建一项任务，让 Aidente 在合适的时间自动照顾电池。"))
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
                            AidenteIconBadge(
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
                            .tint(task.action.colors.first ?? AidenteTheme.jade)

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
                                    .foregroundStyle(AidenteTheme.coral)
                            }
                            .buttonStyle(.borderless)
                            .help(AidenteL10n.t("删除任务"))
                        }
                        .padding(.vertical, 3)

                        if index < scheduleStore.tasks.count - 1 {
                            AidenteRowDivider()
                        }
                    }
                }

                Button {
                    showingNewTask = true
                } label: {
                    Label(AidenteL10n.t("添加计划任务"), systemImage: "plus.circle.fill")
                }
                .buttonStyle(AidenteActionButtonStyle(colors: AidenteTheme.automationColors))
            }

            AidenteCard(
                "Apple 快捷指令",
                subtitle: "在“快捷指令”中使用“打开 URL”操作，即可控制 Aidente。",
                icon: "wand.and.stars.inverse",
                colors: AidenteTheme.dashboardColors
            ) {
                AidenteInsetPanel {
                    Text(
                        """
                        aidente://set-limit?value=80
                        aidente://top-up
                        aidente://calibrate
                        aidente://pause
                        aidente://discharge?value=70
                        aidente://resume
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
            AidenteSettingsBackground()

            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    AidenteIconBadge(
                        icon: "calendar.badge.plus",
                        colors: AidenteTheme.automationColors,
                        size: 44
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AidenteL10n.t("添加计划任务"))
                            .font(.title2.bold())
                        Text(AidenteL10n.t("选择动作、执行时间和重复规则"))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                AidenteCard(
                    "任务设置",
                    icon: "slider.horizontal.3",
                    colors: AidenteTheme.automationColors
                ) {
                    AidenteControlRow(
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
                        AidenteRowDivider()
                        AidenteControlRow(
                            AidenteL10n.t(
                                action == .setChargeLimit ? "充电上限" : "放电目标"
                            ),
                            icon: "percent",
                            colors: AidenteTheme.chargingColors
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

                    AidenteRowDivider()
                    AidenteControlRow(
                        "首次执行",
                        icon: "clock.badge.fill",
                        colors: AidenteTheme.generalColors
                    ) {
                        DatePicker(
                            "",
                            selection: $nextRun
                        )
                        .labelsHidden()
                    }

                    AidenteRowDivider()
                    AidenteControlRow(
                        "重复",
                        icon: "repeat.circle.fill",
                        colors: AidenteTheme.dashboardColors
                    ) {
                        Picker("", selection: $repeatRule) {
                            ForEach(ScheduleRepeatRule.allCases) { rule in
                                Text(rule.title).tag(rule)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }

                    AidenteRowDivider()
                    AidenteSettingToggle(
                        "错过后尽快补做",
                        subtitle: "Mac 唤醒并运行 Aidente 后执行",
                        icon: "arrow.clockwise.circle.fill",
                        colors: AidenteTheme.automationColors,
                        isOn: $runAtNextOpportunity
                    )
                }

                HStack {
                    Button(AidenteL10n.t("取消")) {
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
                        Label(AidenteL10n.t("添加任务"), systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(AidenteActionButtonStyle(colors: AidenteTheme.automationColors))
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
        case .setChargeLimit: AidenteTheme.chargingColors
        case .startCalibration: AidenteTheme.dashboardColors
        case .topUp: AidenteTheme.automationColors
        case .pauseCharging: [AidenteTheme.coral, AidenteTheme.amber]
        case .dischargeTo: AidenteTheme.generalColors
        }
    }
}
