//
//  AppSettings.swift
//  DeepSeek
//
//  Created by ahu on 2025/10/22.
//

import SwiftUI
import KeyboardShortcuts
import Foundation
import AppKit
internal import Combine

// 应用设置类，用于存储用户首选项
class AppUserSettings: ObservableObject {
    static let shared = AppUserSettings()
    
    // 使用UserDefaults存储CSS开关状态
    @Published var isCustomCSSEnabled: Bool
    
    // 可自定义的CSS文件目录路径
    @Published var cssFileDirectory: String
    
    // 存储CSS目录的UserDefaults键
    private let cssDirectoryKey = "customCSSDirectory"
    
    private init() {
        // 初始化时从UserDefaults读取设置
        let hasRunBefore = UserDefaults.standard.bool(forKey: "hasRunBefore")
        if hasRunBefore {
            isCustomCSSEnabled = UserDefaults.standard.bool(forKey: "isCustomCSSEnabled")
            // 读取自定义CSS目录，如果没有则使用默认值
            if let savedDirectory = UserDefaults.standard.string(forKey: cssDirectoryKey) {
                cssFileDirectory = savedDirectory
            } else {
                cssFileDirectory = NSHomeDirectory() + "/.DeepSeek"
            }
        } else {
            // 第一次运行，设置默认值为true
            isCustomCSSEnabled = true
            cssFileDirectory = NSHomeDirectory() + "/.DeepSeek"
            UserDefaults.standard.set(true, forKey: "isCustomCSSEnabled")
            UserDefaults.standard.set(cssFileDirectory, forKey: cssDirectoryKey)
            UserDefaults.standard.set(true, forKey: "hasRunBefore")
        }
        
        // 监听isCustomCSSEnabled的变化
        NotificationCenter.default.addObserver(self, selector: #selector(handleCustomCSSToggle), name: NSNotification.Name("customCSSToggleRequest"), object: nil)
    }
    
    // 保存CSS目录路径
    func saveCSSDirectory(_ directory: String) {
        cssFileDirectory = directory
        UserDefaults.standard.set(directory, forKey: cssDirectoryKey)
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
    @State private var editingDirectory: String
    @State private var lastSavedDirectory: String // 用于跟踪上次保存的目录值
    // 保存成功提示状态
    @State private var showSaveSuccessAlert = false
    
    // 显示保存成功提示
    private func showSaveSuccess() {
        showSaveSuccessAlert = true
    }
    
    init() {
        // 直接从UserDefaults读取设置，确保状态持久化
        let savedValue = UserDefaults.standard.bool(forKey: "isCustomCSSEnabled")
        _localToggleValue = State(initialValue: savedValue)
        
        // 初始化编辑中的目录路径
        var initialDir = NSHomeDirectory() + "/.DeepSeek"
        if let savedDirectory = UserDefaults.standard.string(forKey: "customCSSDirectory") {
            initialDir = savedDirectory
        }
        
        _editingDirectory = State(initialValue: initialDir)
        _lastSavedDirectory = State(initialValue: initialDir)
    }
    
    // 打开访达选择目录
    private func openDirectoryPicker() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        
        // 设置默认路径为当前编辑的目录
        if !editingDirectory.isEmpty {
            let defaultURL = URL(fileURLWithPath: editingDirectory)
            openPanel.directoryURL = defaultURL
        }
        
        openPanel.begin { result in
            guard result == .OK, let url = openPanel.url else {
                return
            }
            
            // 更新编辑中的目录路径
            editingDirectory = url.path
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 快捷键设置区域
            Section {
                HStack {
                    Text("开关应用").frame(width: 100, alignment: .leading)
                    KeyboardShortcuts.Recorder(for: .toggleWindow)
                }
                HStack {
                    Text("刷新页面").frame(width: 100, alignment: .leading)
                    KeyboardShortcuts.Recorder(for: .refreshWeb)
                }
            } header: {
                Text("快捷键")
                    .font(.system(size: 18, weight: .semibold)) // 增大标题字号
                    .padding(.bottom, 8)
            }
            
            // 添加分割线
            Divider()
                .padding(.vertical, 8)
            
            // 外观设置区域
            Section {
                Toggle("启用自定义CSS", isOn: $localToggleValue)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor)) // 显式设置为开关样式
                    .onChange(of: localToggleValue) { _, newValue in
                        // 使用公开方法更改CSS开关状态
                        AppUserSettings.shared.toggleCustomCSS(newValue)
                    }
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义CSS文件目录：")
                    HStack(spacing: 8) {
                        TextField("CSS目录路径", text: $editingDirectory)
                            .font(.system(size: 12))
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        Button(action: {
                            // 打开访达选择目录
                            openDirectoryPicker()
                        }) {
                            Text("选择目录")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        Button(action: {
                            // 保存修改后的目录路径
                            settings.saveCSSDirectory(editingDirectory)
                            // 更新上次保存的值
                            lastSavedDirectory = editingDirectory
                            // 显示保存成功提示
                            showSaveSuccess()
                        }) {
                            Text("保存")
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(editingDirectory == lastSavedDirectory ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .disabled(editingDirectory == lastSavedDirectory) // 当内容未改变时禁用按钮
                    }
                    Text("请将custom.css文件放在以上目录中")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("外观")
                    .font(.system(size: 18, weight: .semibold)) // 增大标题字号
                    .padding(.bottom, 8)
            }
        }        
        .padding(16)
        .frame(width: 600, alignment: .top)
        .alert(isPresented: $showSaveSuccessAlert) {
            Alert(
                title: Text("保存成功"),
                message: Text("CSS目录已成功保存。应用重启后将使用新路径。"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
}
