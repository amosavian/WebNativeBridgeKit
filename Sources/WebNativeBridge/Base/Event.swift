//
//  Event.swift
//
//
//  Created by Amir Abbas Mousavian on 7/17/24.
//

import AnyCodable
import Combine
import Foundation
import WebKit

@MainActor
final class EventManager {
    private var _webViews: NSHashTable<WKWebView>
    
    var webViews: Set<WKWebView> {
        Set(_webViews.allObjects)
    }
    
    init() {
        self._webViews = .init(options: .weakMemory)
    }
    
    func append(_ webView: WKWebView) {
        _webViews.add(webView)
    }
    
    func post(event: CustomEvent) async throws {
        for webView in webViews {
            _ = try await webView.evaluateJavaScript(event.dispatchScript())
        }
    }
}

struct CustomEvent: Sendable {
    let name: String
    let details: [String: any Encodable & Sendable]
    
    func dispatchScript() -> String {
        let detailsCodable = AnyCodable(details)
        let detail = try! String(decoding: JSONEncoder().encode(detailsCodable), as: UTF8.self)
        return """
        customEvent = new CustomEvent("nativeInterface.\(name)", {
          detail: \(detail),
        });
        element.dispatchEvent(customEvent);
        customEvent = null;
        """
    }
}
