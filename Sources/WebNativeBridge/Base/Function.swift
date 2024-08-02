// The Swift Programming Language
// https://docs.swift.org/swift-book

import WebKit

public enum FunctionError: Error {
    case missingName
}

@frozen
public struct ModuleName: StringRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

@frozen
public struct FunctionName: StringRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

@frozen
public struct FunctionArgumentKeyword: StringRepresentable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public typealias FunctionArguments = [FunctionArgumentKeyword: any Sendable]

public typealias FunctionSignature = (_ context: FunctionContext, _ arguments: FunctionArguments) async throws -> (any Encodable & Sendable)?
