//
//  Functions.swift
//  BlueConnect
//
//  GitHub Repo and Documentation: https://github.com/danielepantaleone/BlueConnect
//
//  Copyright © 2024 Daniele Pantaleone. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

@preconcurrency import CoreBluetooth
import Foundation

/// Register a callback in the provided store mapping it over the provided key.
///
/// - Parameters:
///   - store: The registry storing arrays of callbacks associated with their respective key.
///   - key: The key used to map the callback.
///   - callback: A closure that will be invoked when a `Result<T, Error>` is available for the specified key.
func registerCallback<KeyType: Hashable, ValueType>(
    store: inout [KeyType: [(Result<ValueType, Error>) -> Void]],
    key: KeyType,
    callback: ((Result<ValueType, Error>) -> Void)?
) {
    guard let callback else {
        return
    }
    if store[key] == nil {
        store[key] = []
    }
    store[key]?.append(callback)
}

/// Registers a callback.
///
/// - Parameters:
///   - store: The callback store to register the callback in.
///   - callback: The callback to register.
func registerCallback<ValueType>(
    store: inout [(Result<ValueType, Error>) -> Void],
    callback: ((Result<ValueType, Error>) -> Void)?
) {
    guard let callback else {
        return
    }
    store.append(callback)
}

/// Notifies registered callbacks with a result.
///
/// - Parameters:
///   - store: The registry holding the callbacks to notify.
///   - key: The key used to retrieve the list of callbacks to notify.
///   - value: The result to pass to the callbacks.
func notifyCallbacks<KeyType: Hashable, ValueType>(
    store: inout [KeyType: [(Result<ValueType, Error>) -> Void]],
    key: KeyType,
    value: Result<ValueType, Error>
) {
    guard let callbacks = store[key] else {
        return
    }
    store[key] = []
    for callback in callbacks {
        callback(value)
    }
}

/// Notifies all registered callbacks and clears the callbacks store.
///
/// - Parameters:
///   - store: The callback store to notify.
///   - value: The result to pass to the callbacks.
func notifyCallbacks<ValueType>(
    store: inout [(Result<ValueType, Error>) -> Void],
    value: Result<ValueType, Error>
) {
    let callbacks = store
    store.removeAll()
    for callback in callbacks {
        callback(value)
    }
}
