//
//  JSBridge.swift
//  UAgent
//
//  Created by wayne on 2021/9/3.
//  Copyright © 2021 GCI. All rights reserved.
//

import Foundation
import WebKit

public enum JSBridgeZError: Error {
    case dataError
}

public enum JSBridgeZType {
    case double(Double)
    case int(Int)
    case string(String)
    case bool(Bool)
    case null
    case undefined
    case ditionary([String:Any])
    
    func stringValue() -> String {
        switch self {
        case .double(let double):
            return "\(double)"
        case .int(let int):
            return "\(int)"
        case .string(let string):
            return "\"\(string)\""
        case .bool(let bool):
            return bool ? "true" : "false"
        case .null:
            return "null"
        case .undefined:
            return "undefined"
        case .ditionary(let dict):
            if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options:[]),
               let string = String.init(data: jsonData, encoding: String.Encoding.utf8) {
                return string
            } else {
                return ""
            }
        }
    }
}


public extension WKWebView {
    
    private struct AssociatedKeys {
        static var jsBridge = "JS_BRIDGE"
        static var deallocated = "deallocated"
    }
    
    /// webView桥接对象
    var bridge:JSBridgeZ {
        get {
            if let _bridge = objc_getAssociatedObject(self, &AssociatedKeys.jsBridge) as? JSBridgeZ {
                return _bridge
            } else {
                let _bridge = JSBridgeZ(self)
                self.deallocated.disposed {[weak _bridge] in _bridge?.uninjectJS() }
                objc_setAssociatedObject(self, &AssociatedKeys.jsBridge, _bridge, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return _bridge
            }
        }
    }
    
    /// 用于自动释放 JSBridge对象，或者手动调用 JSBridage.uninjectJS()方法手工释放
    fileprivate class Deallocated:NSObject {
        var handler:(()->())?
        func disposed(_ handler:@escaping ()->()) { self.handler = handler }
        deinit { handler?() }
    }
    
    fileprivate var deallocated:Deallocated {
        get {
            if let _deallocated = objc_getAssociatedObject(self, &AssociatedKeys.deallocated) as? Deallocated {
                return _deallocated
            } else {
                let _deallocated = Deallocated()
                objc_setAssociatedObject(self, &AssociatedKeys.deallocated, _deallocated, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return _deallocated
            }
        }
    }
}

public class JSBridgeZ: NSObject {
    public typealias Callback = (JSBridgeZType?) -> Void
    public typealias Handler = (Any,Callback) -> Void
    
    private var handlers: [String: Handler] = [:]
    
    private weak var webView:WKWebView?
    //不能用weak,weak不能保证先释放JsBridge,再释放userContentController,后面手工释放
    private var userContentController: WKUserContentController?
    
    /// 桥接名称
    private var name:String = "bridge"
    /// js脚本代码
    private var variableScripts:[String] = []
    private var handlerScripts:[String] = []
    
    init(_ webView:WKWebView,brigeName:String? = nil) {
        super.init()
        self.webView = webView
        self.userContentController = webView.configuration.userContentController
        self.name = brigeName ?? self.name
    }
    
    /// js对象名称
    ///
    /// - 参数
    ///   - name: 对象名称
    public func set(name:String) -> Self {
        self.name = name
        return self
    }
    
    /// 给js添加变量
    ///
    /// - 参数：
    ///   - key: 变量名称
    ///   - value: 变量值
    public func addVariable(key:String,value:JSBridgeZType) -> Self {
        let script = "var \(key) = \(value.stringValue())"
        variableScripts.append(script)
        return self
    }
    
    /// 给js添加原生方法
    ///
    /// - 参数：
    ///   - name: 方法名称
    ///   - params: 参数列表
    ///   - handler: js调用后的执行方法
    ///   - callback: js调用原生方法后的回调
    public func addHanlder(name:String,params:[String] = [],handler:@escaping Handler) -> Self {
        handlers[name] = handler
        
        let paramsString = createParams(params)
        let postParamsString = createPostParams(params)
        
        let script = "\"\(name)\":function(\(paramsString)){ " +
            "   var response = {\(postParamsString)};" +
            "   if (callback !== undefined) { " +
            "       \(self.name).callbackId += 1;" +
            "       response[\"callbackId\"] = \(self.name).callbackId;" +
            "       \(self.name).callbacks[\(self.name).callbackId] = callback; " +
            "   }" +
            "   window.webkit.messageHandlers.\(name).postMessage(response);" +
            "}"
        handlerScripts.append(script)
        return self
    }
    
    /// 调用js方法的参数列表，默认带一个callback
    ///
    /// - 参数:
    ///   - params: 参数列表
    private func createParams(_ params:[String]) -> String {
        var paramsString = params.joined(separator: ",")
        if !paramsString.isEmpty {
            paramsString += ","
        }
        paramsString += "callback"
        return paramsString
    }
    
    /// 调用原生方法的参数列表，如果有callback，就返回callbackId，返之没有
    ///
    /// - 参数:
    ///   - params: 参数列表
    private func createPostParams(_ params:[String]) -> String {
        return params.map { "\"\($0)\":\($0)" }.joined(separator: ",")
    }
    
    /// 注入js代码
    public func injectJS() {
        injectVariableScripts()
        injectHandlerScripts()
    }
    
    /// 添加js变量代码
    private func injectVariableScripts() {
        guard !variableScripts.isEmpty else { return }
        variableScripts.forEach { script in
            let script = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            userContentController?.addUserScript(script)
        }
    }
    
    /// 添加原生方法调用代码
    private func injectHandlerScripts() {
        guard !handlerScripts.isEmpty else { return }
        
        handlers.forEach { name,handler in
            userContentController?.add(self, name: name)
        }
        
        // 增加回调支持
        handlerScripts.append(createCallBackScript())
        
        var result = "\(name) = { "
        handlerScripts.insert("\"callbackId\":0,\"callbacks\":{}", at: 0)
        result += handlerScripts.joined(separator: ",")
        result += "}"
        
        let script = WKUserScript(source: result, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController?.addUserScript(script)
    }
    
    private func createCallBackScript() -> String {
        return
            "\"nativeCallback\":function(callbackId,result) {" +
            "     var handler = \(self.name).callbacks[callbackId];" +
            "       if (handler !== undefined) {" +
            "          handler(result);" +
            "      } " +
            "}"
    }
    
    /// 调用js方法
    ///
    /// - 参数:
    ///   - functionName: 方法名称
    ///   - params: 参数列表
    ///   - completionHandler: 调用完成，当有错误时，返回error,返之返回js方法的返回值
    @discardableResult
    public func callJs(functionName: String, params: [JSBridgeZType] = [], completionHandler: ((Any?, Error?) -> Void)? = nil) -> Self {
        let paramsString = params.map({$0.stringValue()}).joined(separator: ",")
        let function = "\(functionName)(\(paramsString));"
        webView?.evaluateJavaScript(function, completionHandler: completionHandler)
        return self
    }
    
    /// 取消js注入，释放对象
    public func uninjectJS() {
        handlers.forEach { name,_ in
            userContentController?.removeScriptMessageHandler(forName: name)
        }
        //手动释放
        userContentController = nil
    }
}

extension JSBridgeZ: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let handler = handlers[message.name] else {
            return
        }
        
        // 判断是否存在回调
        var callbackId:Int? = nil
        if let dic = message.body as? [String:Any],
           let id = dic["callbackId"] as? Int {
            callbackId = id
        }
        
        handler(message.body) { value in
            // 回调js
            if let id = callbackId {
                var params:[JSBridgeZType] = [.int(id)]
                if let value = value { params.append(value) }
                callJs(functionName: "\(self.name).nativeCallback",params: params)
            }
        }
    }
}


