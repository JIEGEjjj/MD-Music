import Foundation

/// 内置第三方解锁源。
/// kind：paid-lx、paid-cr、paid-qt 分别对应三种插件运行时格式。
/// template：请求 URL 模板，支持 {id}、{source}、{quality} 占位符。
/// headers：可选的请求头与内置元数据。
struct ThirdPartySource: Identifiable, Codable, Hashable, Sendable {
    var id = UUID().uuidString
    var name: String
    var kind: String = "keyword"
    var template: String
    var urlPath: String = "url"
    var headers: [String: String] = [:]
    var enabled: Bool = true
    var isPreset: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, kind, template, urlPath, headers, enabled, isPreset
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        kind: String = "keyword",
        template: String,
        urlPath: String = "url",
        headers: [String: String] = [:],
        enabled: Bool = true,
        isPreset: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.template = template
        self.urlPath = urlPath
        self.headers = headers
        self.enabled = enabled
        self.isPreset = isPreset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未命名音源"
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "keyword"
        template = try container.decodeIfPresent(String.self, forKey: .template) ?? ""
        urlPath = try container.decodeIfPresent(String.self, forKey: .urlPath) ?? "url"
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        isPreset = try container.decodeIfPresent(Bool.self, forKey: .isPreset) ?? false
    }
}

/// 用户导入的 LX 脚本音源（LX Music 兼容自定义源脚本）
struct LxScriptSource: Identifiable, Codable, Hashable, Sendable {
    var id = UUID().uuidString
    var name: String
    var script: String

    enum CodingKeys: String, CodingKey { case id, name, script }

    init(id: String = UUID().uuidString, name: String, script: String) {
        self.id = id
        self.name = name
        self.script = script
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未命名 LX 音源"
        script = try container.decodeIfPresent(String.self, forKey: .script) ?? ""
    }
}

/// 内置音源管理：首次启动时写入三种插件格式对应的预设。
final class UnblockSourceStore: ObservableObject {
    static let shared = UnblockSourceStore()

    private static let paidAPIURL = "https://source.shiqianjiang.cn/api/music"
    private static let paidAPIKey = "CERU_KEY-51440644-C9AD-4E10-B593-258FF59CF259"
    private static let paidURLTemplate = "\(paidAPIURL)/url?source={source}&songId={id}&quality={quality}"

    /// 来自用户提供的三个脚本：LX、CeruMusic CR、CeruMusic QT。
    /// 三个脚本最终调用同一个 API，播放时会按请求指纹去重，避免同一首歌重复请求三次。
    static let paidPresetSources: [ThirdPartySource] = [
        ThirdPartySource(
            id: "beans.preset.shiqianjiang.lx.v7",
            name: "聆澜音源 · LX",
            kind: "paid-lx",
            template: paidURLTemplate,
            headers: ["apiKey": paidAPIKey, "quality": "320k"],
            isPreset: true
        ),
        ThirdPartySource(
            id: "beans.preset.shiqianjiang.cr.v7",
            name: "聆澜音源 · CR",
            kind: "paid-cr",
            template: paidURLTemplate,
            headers: ["apiKey": paidAPIKey, "quality": "320k"],
            isPreset: true
        ),
        ThirdPartySource(
            id: "beans.preset.shiqianjiang.qt.v7",
            name: "聆澜音源 · QT",
            kind: "paid-qt",
            template: paidURLTemplate,
            headers: ["apiKey": paidAPIKey, "quality": "320k"],
            isPreset: true
        ),
        // 免费兜底源：聆澜 API 的共享 Key 每日仅 1000 次成功配额，全用户共用，
        // 配额耗尽当天所有 VIP 解析都会失败（HTTP 200 + 错误 JSON，解析为空后自动轮到下一个源）。
        // 以下两个源无配额限制，作为兜底保证 QQ / 网易云 VIP 歌曲全天可播。
        ThirdPartySource(
            id: "beans.preset.md.guoyue.qq.v1",
            name: "MD 兜底 · QQ 稳定源",
            kind: "template-api",
            template: "https://cyapi.top/API/qq_music.php?apikey=1ffdf5733f5d538760e63d7e46ba17438d9f7b9dfc18c51be1109386fd74c3a1&type=json&mid={id}",
            headers: ["source": "tx"],
            isPreset: true
        ),
        ThirdPartySource(
            id: "beans.preset.md.guoyue.wy.v1",
            name: "MD 兜底 · 网易云统一源",
            kind: "template-api",
            template: "https://music-api.gdstudio.xyz/api.php?types=url&source=netease&id={id}&br=999",
            headers: ["source": "wy"],
            isPreset: true
        ),
    ]

    @Published var presetSources: [ThirdPartySource] {
        didSet { save() }
    }

    /// 用户导入的 LX 脚本音源（作为解析链最后一级兜底）
    @Published var lxScripts: [LxScriptSource] = [] {
        didSet { saveLxScripts() }
    }

    private let defaults = UserDefaults.standard
    private let presetsKey = "beans.unblock.presets"
    private let lxScriptsKey = "beans.unblock.lxscripts.v2"
    private let legacyCustomKey = "beans.unblock.custom"
    private let legacyLXKey = "beans.unblock.lxScripts"

    private init() {
        let savedSources: [ThirdPartySource]
        if let data = defaults.data(forKey: presetsKey),
           let list = try? JSONDecoder().decode([ThirdPartySource].self, from: data) {
            savedSources = list
        } else if let data = defaults.data(forKey: legacyCustomKey),
                  let list = try? JSONDecoder().decode([ThirdPartySource].self, from: data) {
            savedSources = list
        } else {
            savedSources = []
        }

        // 旧版本的导入源和旧版 guoyue 预设不再参与播放，避免导入脚本继续触发网络请求。
        let existingPresets = savedSources.filter { $0.isPreset }
        presetSources = Self.seedPaidPresets(into: existingPresets)
        defaults.removeObject(forKey: legacyCustomKey)
        migrateLegacyLxScripts()
        save()
    }

    /// 上游 1.5.5 移除 LX 时直接清掉了用户脚本数据；MD 恢复该功能，
    /// 从旧键把脚本迁移回来（1.3.x 前升级且未启动过上游版的用户可无损找回）。
    private func migrateLegacyLxScripts() {
        if let data = defaults.data(forKey: lxScriptsKey),
           let list = try? JSONDecoder().decode([LxScriptSource].self, from: data),
           !list.isEmpty {
            lxScripts = list
            return
        }
        if let data = defaults.data(forKey: legacyLXKey),
           let list = try? JSONDecoder().decode([LxScriptSource].self, from: data),
           !list.isEmpty {
            lxScripts = list
            saveLxScripts()
        }
    }

    private func saveLxScripts() {
        if let data = try? JSONEncoder().encode(lxScripts) {
            defaults.set(data, forKey: lxScriptsKey)
        }
    }

    /// 用户导入的自定义源：进入统一源列表，可在设置页开关
    func add(_ source: ThirdPartySource) {
        var updated = source
        if let index = presetSources.firstIndex(where: { $0.id == source.id }) {
            presetSources[index] = updated
        } else {
            updated.isPreset = false
            presetSources.insert(updated, at: 0)
        }
    }

    func addLxScript(_ source: LxScriptSource) {
        lxScripts.removeAll { $0.name == source.name }
        lxScripts.append(source)
    }

    func removeLxScript(_ source: LxScriptSource) {
        lxScripts.removeAll { $0.id == source.id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(presetSources) {
            defaults.set(data, forKey: presetsKey)
        }
    }

    private static func seedPaidPresets(into savedSources: [ThirdPartySource]) -> [ThirdPartySource] {
        var seeded = savedSources
        for preset in paidPresetSources {
            if let index = seeded.firstIndex(where: { $0.id == preset.id }) {
                var updated = preset
                updated.enabled = seeded[index].enabled
                seeded[index] = updated
            } else {
                seeded.append(preset)
            }
        }
        return seeded
    }
}
