import SwiftUI

// MARK: - 版本更新日志（设置页与首次更新弹窗使用）

struct VersionLog: Identifiable {
    let id: String
    let version: String
    let title: String
    let features: [String]
    let fixes: [String]
}

enum ChangelogStore {
    static let lastSeenKey = "beans.lastSeenVersion"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var lastSeenVersion: String {
        UserDefaults.standard.string(forKey: lastSeenKey) ?? ""
    }

    static func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenKey)
    }

    static var shouldShowWhatsNew: Bool {
        !lastSeenVersion.isEmpty && lastSeenVersion != currentVersion
    }

    static var latest: VersionLog? { logs.first }

    static let logs: [VersionLog] = [
        VersionLog(
            id: "1.3.1",
            version: "1.3.1",
            title: "修复 QQ / 酷狗 VIP 歌曲无法播放",
            features: [
                "新增两个免费兜底音源（无配额限制）：收费源每日配额耗尽后自动接管 VIP 解析",
                "兜底源覆盖 QQ 音乐与网易云音乐 VIP 歌曲",
            ],
            fixes: [
                "修复共享解析源每日配额耗尽导致 VIP 歌曲全天无法播放的问题",
                "修复加载失败后点击播放会播放上一首歌的问题，现在会自动重试当前歌曲",
            ]
        ),
        VersionLog(
            id: "1.3.0",
            version: "1.3.0",
            title: "同步上游 1.5.5 与登录体验改进",
            features: [
                "同步上游 1.5.5 全部改进（上游移除了 LX 脚本音源，本版本跟随移除）",
                "播放器顶栏标题区可点击打开更多操作菜单",
                "支持 iPhone 高刷新率声明（CADisableMinimumFrameDurationOnPhone）",
                "新增网页登录数据清理器，登录状态更干净",
                "随机播放、锁屏封面与播放进度刷新沿用本项目的优化实现",
            ],
            fixes: [
                "包含上游 1.5.5 的各项修复与稳定性改进",
                "保留封面共享缓存、缩略图、接口独立降级等全部既有优化",
            ]
        ),
        VersionLog(
            id: "1.2.0",
            version: "1.2.0",
            title: "主页加载修复与启动提速",
            features: [
                "主页各板块独立加载：单个来源失败不再拖垮整页，刷不出来时下拉重试即可",
                "首页封面全面改用缩略图并支持降采样解码，进入 App 和首页滚动明显更流畅",
                "首页刷新改为静默刷新，不再把已有内容闪成加载转圈",
                "壁纸备份仅在变化时写回，启动更轻快",
                "免责声明确认前不再预加载网络内容",
            ],
            fixes: [
                "修复连续收藏网易云和 QQ 歌曲时其中一个收藏本地记录丢失的问题",
                "修复上滑关闭 App 可能丢失最近新建歌单 / 收藏的问题",
                "修复随机模式删除正在播放的歌后，下一首可能重播当前歌的问题",
                "修复快速切歌时锁屏封面可能显示上一首封面的问题",
                "修复封面命中缓存时仍闪一帧占位图的问题",
            ]
        ),
        VersionLog(
            id: "1.0.0",
            version: "1.0.0",
            title: "MD Music 首个版本",
            features: [
                "基于 Beans Music 1.5.4 定制：聚合网易云音乐 / QQ 音乐 / 酷狗",
                "自定义应用图标与欢迎页",
                "LX 脚本音源支持，可导入第三方音源脚本",
                "包含长歌名布局、歌手主页分页加载、酷狗加载风暴等上游全部修复",
                "更新检测指向本仓库，App 内更新直接下载自建版本",
            ],
            fixes: [
                "修复上游遗漏的两处编译错误，首发即完整可构建",
            ]
        )
    ]
}

// MARK: - 更新说明弹窗

struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    if let log = ChangelogStore.latest {
                        VersionLogCard(log: log)
                            .padding(16)
                    }
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("更新说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始使用") {
                        ChangelogStore.markSeen()
                        dismiss()
                    }
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansAmber)
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large]))
    }
}

struct ChangelogListView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(ChangelogStore.logs) { log in
                            VersionLogCard(log: log)
                        }
                    }
                    .padding(16)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("更新日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large]))
    }
}

private struct VersionLogCard: View {
    let log: VersionLog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("v\(log.version)")
                    .font(BeansFont.appFont(16, .bold))
                    .foregroundStyle(Color.beansAmber)
                Text(log.title)
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansLabel)
            }
            if !log.features.isEmpty {
                logSection(title: "新增功能", icon: "plus.circle.fill", items: log.features)
            }
            if !log.fixes.isEmpty {
                Divider().overlay(Color.beansComment.opacity(0.15))
                logSection(title: "问题修复", icon: "checkmark.circle.fill", items: log.fixes)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .beansCardShadow(radius: 9, y: 3)
    }

    private func logSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BeansFont.appFont(14, .bold))
                .foregroundStyle(Color.beansAmber)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansAmber)
                        .padding(.top, 2)
                    Text(item)
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - 软件使用说明

struct UsageGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(title: String, icon: String, lines: [String])] = [
        (
            "应用简介",
            "music.note.house.fill",
            ["MD Music 是一款聚合网易云音乐、QQ 音乐与酷狗音乐歌单同步能力的第三方音乐播放器客户端，仅供个人学习研究使用。"]
        ),
        (
            "多平台切换",
            "arrow.left.arrow.right",
            ["首页和搜索保留网易云 / QQ 音乐入口；音乐库可同步网易云、QQ 音乐与酷狗云端歌单。"]
        ),
        (
            "账号服务",
            "person.crop.circle.badge.checkmark",
            ["「我的」页面可统一管理账号登录。登录后会同步对应平台歌单与账号状态。"]
        ),
        (
            "播放体验",
            "play.circle.fill",
            ["全屏播放器支持歌词、进度跳转、倍速、定时关闭、循环模式与音质选择。歌词不同步时可在播放器设置中微调偏移。"]
        ),
        (
            "个性化定制",
            "paintpalette.fill",
            ["支持自定义壁纸、主题色、歌词样式与底部布局。"]
        )
    ]

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: section.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.beansAmber)
                                    Text(section.title)
                                        .font(BeansFont.appFont(14, .bold))
                                        .foregroundStyle(Color.beansLabel)
                                }
                                ForEach(section.lines, id: \.self) { line in
                                    Text(line)
                                        .font(BeansFont.appFont(12.5))
                                        .foregroundStyle(Color.beansLabel.opacity(0.85))
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .beansCardShadow(radius: 8, y: 3)
                        }
                        Text("MD Music · 仅供学习交流 · 音乐版权归各平台所有 · 酷狗音乐名称及图标归酷狗音乐 / 腾讯音乐娱乐相关权利方所有")
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("软件使用说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.large]))
    }
}
