// The Swift Programming Language
// https://docs.swift.org/swift-book

import WebKit

public enum FunctionError: Error {
    case missingName
}

@frozen
public struct FunctionName: StringRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

@frozen
public struct FunctionArgumentName: StringRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public typealias FunctionArguments = [FunctionArgumentName: any Sendable]

public typealias FunctionSignature = (_ context: FunctionContext, _ arguments: FunctionArguments) async throws -> (any Encodable & Sendable)?

public struct FrameInfo: Sendable {
    public let url: URL?
    public let securityOrigin: URL?
    public let isMainFrame: Bool
    public let webView: WKWebView?
    
    @MainActor
    init(frame: WKFrameInfo) {
        self.url = frame.request.url
        self.securityOrigin = frame.securityOrigin.url
        self.isMainFrame = frame.isMainFrame
        self.webView = frame.webView
    }
}

public struct FunctionContext: Sendable {
    public let webView: WKWebView?
    public let frameInfo: FrameInfo
    
    init(webView: WKWebView?, frameInfo: FrameInfo) {
        self.webView = webView
        self.frameInfo = frameInfo
    }
    
    @MainActor
    init(_ message: WKScriptMessage) {
        self.webView = message.webView
        self.frameInfo = .init(frame: message.frameInfo)
    }
    
    @MainActor
    public func checkSameSecurityOrigin() -> Bool {
        guard let mainURL = webView?.url else {
            return false
        }
        return mainURL.host == frameInfo.securityOrigin?.host
    }
}

extension WKSecurityOrigin {
    public var url: URL? {
        var securityOrigin = URLComponents()
        securityOrigin.scheme = self.protocol
        securityOrigin.host = host
        securityOrigin.port = port
        return securityOrigin.url
    }
}
