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

@frozen
public struct EventName: StringRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension WKWebView: CancellableContainer {
    @MainActor
    public func registerEvents<M: Module>(module: M.Type) {
        for (key, value) in module.events {
            value
                .sink { @MainActor [weak self] details in
                    let detailsCodable = AnyCodable(details)
                    let detailsValue = try! String(decoding: JSONEncoder().encode(detailsCodable), as: UTF8.self)
                    let script =
                        """
                        customEvent = new CustomEvent("\(module.name).\(key)", {
                          details: \(detailsValue),
                        });
                        element.dispatchEvent(customEvent);
                        customEvent = null;
                        """
                    self?.evaluateJavaScript(script)
                }
                .store(in: &cancellableStorage)
        }
    }
}

public typealias EventPublisher = AnyPublisher<[String: any Encodable & Sendable]?, Never>

extension NotificationCenter {
    func webEvent(
        for name: Notification.Name,
        _ userInfoHandler: (([AnyHashable: Any]) -> EventPublisher.Output)? = nil
    ) -> EventPublisher {
        NotificationCenter.default
            .publisher(for: name)
            .receive(on: DispatchQueue.main)
            .map { notification -> EventPublisher.Output in
                userInfoHandler?(notification.userInfo ?? [:])
            }
            .eraseToAnyPublisher()
    }
}
