//
//  AppSettings.swift
//  DeepSeek
//
//  Created by ahu on 2025/10/22.
//

import SwiftUI
import KeyboardShortcuts
internal import Combine

// 应用设置类，用于存储用户首选项
class AppUserSettings: ObservableObject {
    static let shared = AppUserSettings()
    
    // 使用UserDefaults存储CSS开关状态
    @Published var isCustomCSSEnabled: Bool
    
    // 获取CSS文件目录路径
    var cssFileDirectory: String {
        return NSHomeDirectory() + "/.DeepSeek"
    }
    
    private init() {
        // 初始化时从UserDefaults读取设置
        let hasRunBefore = UserDefaults.standard.bool(forKey: "hasRunBefore")
        if hasRunBefore {
            isCustomCSSEnabled = UserDefaults.standard.bool(forKey: "isCustomCSSEnabled")
        } else {
            // 第一次运行，设置默认值为true
            isCustomCSSEnabled = true
            UserDefaults.standard.set(true, forKey: "isCustomCSSEnabled")
            UserDefaults.standard.set(true, forKey: "hasRunBefore")
        }
        
        // 监听isCustomCSSEnabled的变化
        NotificationCenter.default.addObserver(self, selector: #selector(handleCustomCSSToggle), name: NSNotification.Name("customCSSToggleRequest"), object: nil)
    }
    
    // 公开的方法来更改CSS开关状态
    func toggleCustomCSS(_ enabled: Bool) {
        if isCustomCSSEnabled != enabled {
            isCustomCSSEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: "isCustomCSSEnabled")
            // 发送通知，告知WebViewController设置已更改
            NotificationCenter.default.post(name: NSNotification.Name("customCSSToggled"), object: nil)
        }
    }
    
    @objc private func handleCustomCSSToggle(notification: Notification) {
        if let enabled = notification.userInfo?["enabled"] as? Bool {
            toggleCustomCSS(enabled)
        }
    }
}

@available(macOS 13, *)
struct AppSettings: View {
    @StateObject private var settings = AppUserSettings.shared
    @State private var localToggleValue: Bool
    
    init() {
        // 直接从UserDefaults读取设置，确保状态持久化
        let savedValue = UserDefaults.standard.bool(forKey: "isCustomCSSEnabled")
        _localToggleValue = State(initialValue: savedValue)
    }
    
    var body: some View {
        TabView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("开关应用").frame(width: 100, alignment: .leading)
                    KeyboardShortcuts.Recorder(for: .toggleWindow)
                }
                HStack {
                    Text("刷新页面").frame(width: 100, alignment: .leading)
                    KeyboardShortcuts.Recorder(for: .refreshWeb)
                }
            }
            .frame(width: 400, height: 100) // 固定窗口大小
            .padding(0) // 去掉多余 padding
            .tabItem { 
                Text("快捷键")
                    .padding(.vertical, 2) // 调整上下内边距，使tabItem更紧凑
            }
            .tag(0)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Toggle("启用自定义CSS", isOn: $localToggleValue)
                        .frame(width: 200)
                        .onChange(of: localToggleValue) { _, newValue in
                            // 使用公开方法更改CSS开关状态
                            AppUserSettings.shared.toggleCustomCSS(newValue)
                        }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义CSS文件目录：")
                    Text(settings.cssFileDirectory)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                        .lineLimit(2)
                    Text("请将custom.css文件放在以上目录中")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .frame(width: 400, height: 200)
            .tabItem { 
                Text("外观")
                    .padding(.vertical, 2) // 调整上下内边距，使tabItem更紧凑
            }
            .tag(1)
        }
        .frame(width: 450, height: 250)
    }
}
