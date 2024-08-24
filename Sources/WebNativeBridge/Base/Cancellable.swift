//
//  Cancellable.swift
//
//
//  Created by Amir Abbas Mousavian on 8/15/24.
//

import Combine
import Foundation

class Box<Value>: NSObject {
    var value: Value
    
    init(_ value: Value) {
        self.value = value
    }
}

typealias CancellableBox = Box<Set<AnyCancellable>>

protocol CancellableKey {
    nonisolated(unsafe) static var key: Int8 { get set }
}

enum GeneralCancellableKey: CancellableKey {
    nonisolated(unsafe) static var key: Int8 = 0
}

extension CancellableKey where Self == GeneralCancellableKey {
    static var general: GeneralCancellableKey.Type { GeneralCancellableKey.self }
}

protocol CancellableContainer: NSObjectProtocol {
    subscript(_: any CancellableKey.Type) -> Set<AnyCancellable> { get set }
}

extension CancellableContainer {
    subscript(cancellableHandle: any CancellableKey.Type) -> Set<AnyCancellable> {
        get {
            (objc_getAssociatedObject(self, &cancellableHandle.key) as? CancellableBox)?.value ?? []
        }
        set {
            objc_setAssociatedObject(self, &cancellableHandle.key, CancellableBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var cancellableStorage: Set<AnyCancellable> {
        get { self[GeneralCancellableKey.self] }
        set { self[GeneralCancellableKey.self] = newValue }
    }
}
