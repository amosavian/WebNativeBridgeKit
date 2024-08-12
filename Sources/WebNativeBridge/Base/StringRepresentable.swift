//
//  StringRepresentable.swift
//
//
//  Created by Amir Abbas Mousavian on 8/1/24.
//

import Foundation

public protocol StringRepresentable: RawRepresentable<String>, Codable, CodingKeyRepresentable, Hashable, Sendable, LosslessStringConvertible, ExpressibleByStringLiteral {
    init(rawValue: String)
}

extension StringRepresentable {
    public var description: String {
        rawValue
    }
    
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
    
    public init(_ description: String) {
        self.init(rawValue: description)
    }
}
