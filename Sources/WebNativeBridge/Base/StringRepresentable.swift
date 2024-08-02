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
    
    public var codingKey: String {
        rawValue
    }
    
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
    
    public init(_ description: String) {
        self.init(rawValue: description)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(rawValue: container.decode(String.self))
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
