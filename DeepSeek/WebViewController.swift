//
//  WebViewController.swift
//  DeepSeek
//
//  Created by ahu on 2025/10/21.
//

import Cocoa
import WebKit
import Foundation

class WebViewController: NSViewController, WKUIDelegate, WKNavigationDelegate {
    
    private var webView: WKWebView!
    
    override func loadView() {
        let view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        self.view = view
    }
    
    private var observer: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        
        // 添加设置变化的监听
        setupNotificationObserver()
    }
    
    private func setupNotificationObserver() {
        // 移除之前的观察者（如果有）
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // 添加新的观察者，使用weak self避免循环引用
        observer = NotificationCenter.default.addObserver(forName: 
            NSNotification.Name("customCSSToggled"), object: nil, queue: .main) {
            [weak self] notification in
            guard let self = self else { return }
            self.handleCSSToggle()
        }
    }
    
    deinit {
        // 移除观察者
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func handleCSSToggle() {
        // 重置注入状态
        cssInjected = false
        
        if AppUserSettings.shared.isCustomCSSEnabled {
            NSLog("自定义CSS已启用，重新注入")
            // 注入CSS
            injectCustomCSS()
        } else {
            NSLog("自定义CSS已禁用，移除样式")
            // 移除已注入的CSS
            removeCustomCSS()
        }
    }
    
    private func removeCustomCSS() {
        // 移除之前注入的样式元素
        let jsCode = """
        (function() {
            const styleElement = document.getElementById('deepseek-custom-css');
            if (styleElement) {
                styleElement.remove();
                console.log('已移除自定义CSS');
            }
        })();
        """
        
        webView.evaluateJavaScript(jsCode) { (result, error) in
            if let error = error {
                NSLog("移除CSS时发生错误: \(error.localizedDescription)")
            } else {
                NSLog("成功移除自定义CSS")
            }
        }
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "javaScriptEnabled")
        
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        
        // ✅ 设置 WKUIDelegate，否则不会响应文件选择等 UI 操作
        webView.uiDelegate = self
        // ✅ 设置 WKNavigationDelegate，处理链接点击事件
        webView.navigationDelegate = self
        
        view.addSubview(webView)
        
        if let url = URL(string: "https://chat.deepseek.com/") {
            webView.load(URLRequest(url: url))
        }
    }
    
    func reloadWeb() {
        // 重置CSS注入标志，确保刷新页面后重新注入CSS
        cssInjected = false
        webView.reload()
    }
    
    // 显示弹窗消息
    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "DeepSeek"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    // ✅ 处理网页中的 <input type="file">
    func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        
        panel.begin { result in
            if result == .OK {
                completionHandler(panel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    // ✅ 处理链接点击事件，在默认浏览器中打开外部链接
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 检查是否是用户点击链接的操作
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url {
            // 检查是否是外部链接（非deepseek.com域名）
            if let host = url.host,
               !host.contains("deepseek.com") {
                // 在默认浏览器中打开链接
                NSWorkspace.shared.open(url)
                // 取消在webView中的导航
                decisionHandler(.cancel)
                return
            }
        }
        // 允许其他导航操作
        decisionHandler(.allow)
    }
    
    // 是否已经注入过CSS，避免无限循环
    private var cssInjected = false
    
    // ✅ 页面加载完成后注入自定义CSS
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 只在第一次加载完成时注入CSS，避免刷新页面导致的无限循环
        if !cssInjected {
            cssInjected = true
            // 检查是否启用了自定义CSS
            if AppUserSettings.shared.isCustomCSSEnabled {
                injectCustomCSS()
            } else {
                NSLog("自定义CSS已禁用，跳过注入")
            }
        }
    }
    
    // 注入自定义CSS样式
    private func injectCustomCSS() {
        // 再次检查是否启用了自定义CSS，防止在设置更改时执行
        guard AppUserSettings.shared.isCustomCSSEnabled else {
            NSLog("自定义CSS已禁用，取消注入")
            return
        }
        
        // 从AppUserSettings中获取用户保存的CSS目录路径
        let cssDirectory = AppUserSettings.shared.cssFileDirectory
        
        // 自定义CSS文件路径
        let cssFilePath = cssDirectory + "/custom.css"
        
        // 检查并创建应用数据文件夹（如果不存在）
        if !FileManager.default.fileExists(atPath: cssDirectory) {
            do {
                // 创建目录时设置适当的权限
                try FileManager.default.createDirectory(atPath: cssDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
                self.showAlert(message: "已创建应用数据文件夹，请在以下路径创建custom.css文件: \(cssFilePath)")
                return
            } catch {
                self.showAlert(message: "创建应用数据文件夹失败: \(error.localizedDescription)")
                return
            }
        }
        
        // 检查CSS文件是否存在并可读
        if FileManager.default.fileExists(atPath: cssFilePath) {
            // 尝试使用文件URL而不是路径，这样能更好地处理权限
            if let fileURL = URL(string: "file://" + cssFilePath) {
                do {
                    // 读取CSS文件内容
                    let cssContent = try String(contentsOf: fileURL, encoding: .utf8)
                    
                    // 验证CSS内容不为空
                    if cssContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.showAlert(message: "CSS文件内容为空")
                        return
                    }
                    
                    // 确保CSS内容被正确包装在<style>标签中
                    let wrappedCSS = """
                        (function() {
                            // 检查是否已存在我们注入的样式
                            var existingStyle = document.getElementById('deepseek-custom-css');
                            if (existingStyle) {
                                existingStyle.remove();
                            }
                            
                            // 创建新的style标签
                            var style = document.createElement('style');
                            style.id = 'deepseek-custom-css';
                            style.textContent = `\(cssContent)`;
                            document.head.appendChild(style);
                            console.log('DeepSeek自定义CSS已应用');
                            return 'success';
                        })();
                    """
                    
                    // 直接执行JavaScript注入，使用模板字符串避免转义问题
                    webView.evaluateJavaScript(wrappedCSS) { (result, error) in
                        if let error = error {
                            self.showAlert(message: "CSS注入失败: \(error.localizedDescription)")
                            NSLog("CSS注入错误: \(error)")
                        } else {
                            // self.showAlert(message: "CSS注入成功")
                            NSLog("成功注入自定义CSS")
                        }
                    }
                } catch {
                    self.showAlert(message: "读取CSS文件失败: \(error.localizedDescription)。请检查文件权限和内容格式。")
                }
            } else {
                self.showAlert(message: "无效的文件路径: \(cssFilePath)")
            }
        } else {
            // CSS文件不存在，提示用户创建
            self.showAlert(message: "CSS文件不存在，请在以下路径创建custom.css文件: \(cssFilePath)")
        }
    }
}
