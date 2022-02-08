//
//  ViewController.swift
//  JSBridgeZ
//
//  Created by dearwayne on 02/08/2022.
//  Copyright (c) 2022 dearwayne. All rights reserved.
//

import UIKit
import WebKit
import JSBridgeZ

let topHeight = UIApplication.shared.statusBarFrame.height + 44
let screenHeight = UIScreen.main.bounds.height
let screenWidth = UIScreen.main.bounds.width

class ViewController: UIViewController {

    var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        webView = WKWebView(frame: CGRect(x: 0, y: topHeight, width: screenWidth, height: screenHeight - topHeight))
        webView.scrollView.isScrollEnabled = false
        view.addSubview(webView)
        
        webView.bridge
            .set(name: "jsbridge")
            .addHanlder(name: "handle", handler: { (data, callback) in
                print("[js call swift handle]")
            })
            .addHanlder(name: "handleString", params: ["params"], handler: { (data, callback) in
                var str = ""
                if let dic = data as? [String:Any],let params = dic["params"] as? String {
                    str = params
                }
                print("[js call swift handleString] - string: \(str)\n")
                let responseData = "I'm swift response data"
                callback(.string("[response from swift] - response data: \(responseData)"))
            })
            .addHanlder(name: "handleObject", params: ["objc"], handler: { (data, callback) in
                var objc:[String:Any] = [:]
                if let dic = data as? [String:Any],let params = dic["objc"] as? [String:Any] {
                    objc = params
                }
                print("[js call swift handleObject] - object: \(objc)\n")
                let responseData = "I'm swift response data"
                callback(.string("[response from swift] - response data: \(responseData)"))
            })
            .addHanlder(name: "handleArray", params: ["array"], handler: { (data, callback) in
                var array:[Any] = []
                if let dic = data as? [String:Any],let params = dic["array"] as? [Any] {
                    array = params
                }
                print("[js call swift handleArray] - array: \(array)\n")
            })
            .addHanlder(name: "handleCallback",handler: { (_, callback) in
                print("[js call swift handleCallback]")
                let responseData = "I'm swift response data"
                callback(.string("[response from swift] - response data: \(responseData)"))
            })
            .injectJS()
        
        let htmlString = try! String(contentsOfFile: Bundle.main.path(forResource: "index", ofType: "html")!)
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
    
    func uninjectJS() {
        // 支持自动释放，也可以调用这个自动释放
        webView.bridge.uninjectJS()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}

