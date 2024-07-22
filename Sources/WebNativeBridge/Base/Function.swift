// The Swift Programming Language
// https://docs.swift.org/swift-book

@preconcurrency import AnyCodable
import WebKit

public enum FunctionError: Error {
    case missingName
}

@frozen
public struct FunctionName: RawRepresentable, Codable, CodingKeyRepresentable, Hashable, Sendable, LosslessStringConvertible, ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    public let rawValue: String
    
    public var description: String {
        rawValue
    }
    
    public var codingKey: String {
        rawValue
    }
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
    
    public init(_ description: String) {
        self.rawValue = description
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

@frozen
public struct Function: Decodable, ExpressibleByDictionaryLiteral {
    public let name: FunctionName
    public let args: [any Sendable]
    public let kwArgs: [FunctionArgumentKeyword: any Sendable]
    
    private enum CodingKeys: String, CodingKey {
        case name
        case args
        case kwArgs
    }
    
    public init(dictionaryLiteral elements: (String, Any)...) {
        try! self.init(.init(uniqueKeysWithValues: elements))
    }
    
    public init(_ dictionary: [String: Any]) throws {
        guard let name = dictionary[CodingKeys.name.rawValue] as? String else {
            throw FunctionError.missingName
        }
        
        self.name = .init(rawValue: name)
        self.args = dictionary[CodingKeys.args.rawValue] as? [any Sendable] ?? []
        self.kwArgs = dictionary[CodingKeys.kwArgs.rawValue] as? [FunctionArgumentKeyword: any Sendable] ?? [:]
    }
    
    public init(name: FunctionName, args: [any Sendable], kwArgs: [FunctionArgumentKeyword: any Sendable]) {
        self.name = name
        self.args = args
        self.kwArgs = kwArgs
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(FunctionName.self, forKey: .name)
        let args = try container.decodeIfPresent([AnyCodable].self, forKey: .args) ?? []
        self.args = args
        let kwArgs = try container.decodeIfPresent([FunctionArgumentKeyword: AnyCodable].self, forKey: .kwArgs) ?? [:]
        self.kwArgs = kwArgs
    }
}
