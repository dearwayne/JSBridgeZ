# JSBridgeZ

[![CI Status](https://img.shields.io/travis/dearwayne/JSBridgeZ.svg?style=flat)](https://travis-ci.org/dearwayne/JSBridgeZ)
[![Version](https://img.shields.io/cocoapods/v/JSBridgeZ.svg?style=flat)](https://cocoapods.org/pods/JSBridgeZ)
[![License](https://img.shields.io/cocoapods/l/JSBridgeZ.svg?style=flat)](https://cocoapods.org/pods/JSBridgeZ)
[![Platform](https://img.shields.io/cocoapods/p/JSBridgeZ.svg?style=flat)](https://cocoapods.org/pods/JSBridgeZ)


An iOS bridge for sending messages from Swift to JavaScript in WKWebView 

## Requirements

iOS 8.0 WKWebView

## Installation

JSBridgeZ is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'JSBridgeZ'
```

## Usage


1. import JSBridgeZ			
		
	```swift
	import JSBridgeZ
	```

2. Set the bridge name and add handlers in Swift.

	```swift
	webView.bridge
	    .set(name: "jsbridge")
	    .addHanlder(name: "handleObject", params: ["objc"], handler: { (data, callback) in
                var objc:[String:Any] = [:]
                if let dic = data as? [String:Any],let params = dic["objc"] as? [String:Any] {
                    objc = params
                }
                print("[js call swift handleObject] - object: \(objc)\n")
                let responseData = "I'm swift response data"
                callback(.string("[response from swift] - response data: \(responseData)"))
            })
	    .injectJS()
	```
	
3. Call the handler in javascript.

	```JavaScript
	jsbridge.handleObject({ "key": { "key": "value" }, "array": ["value1", "value2"] },function(responseData) {
        log(responseData.toString())
    }));
	```
	
4. See the example for more detail.
	

## License

JSBridgeZ is available under the MIT license. See the LICENSE file for more info.
