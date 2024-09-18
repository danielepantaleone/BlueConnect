//
//  ResultExtensions.swift
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

extension Result {
    
    /// Executes the provided action if the `Result` is a success.
    ///
    /// - Parameter action: A closure to execute if the `Result` is a success. This closure takes the success value as its parameter.
    /// - Returns: The original `Result` instance.
    /// - Note: The closure will be executed only if the `Result` is a `.success`. If the `Result` is a `.failure`, the closure is not executed.
    @discardableResult
    func onSuccess(_ action: (Success) throws -> Void) rethrows -> Self {
        switch self {
            case .success(let success):
                try action(success)
            case .failure:
                break
        }
        return self
    }
    
    /// Executes the provided action if the `Result` is a failure.
    ///
    /// - Parameter action: A closure to execute if the `Result` is a failure. This closure takes the failure error as its parameter.
    /// - Returns: The original `Result` instance.
    /// - Note: The closure will be executed only if the `Result` is a `.failure`. If the `Result` is a `.success`, the closure is not executed.
    @discardableResult
    func onFailure(_ action: (Failure) throws -> Void) rethrows -> Self {
        switch self {
            case .success:
                break
            case .failure(let error):
                try action(error)
        }
        return self
    }
    
    /// Forwards the success result to the provided callback.
    ///
    /// - Parameter callback: An optional closure to execute if the `Result` is a success. This closure takes a `Result` of the same success value type and the original failure type.
    /// - Returns: The original `Result` instance.
    /// - Note: The callback will be executed only if the `Result` is a `.success`. If the `Result` is a `.failure`, the callback is not executed.
    @discardableResult
    func forwardSuccess(to callback: ((Result<Success, Failure>) throws -> Void)?) rethrows -> Self {
        switch self {
            case .success(let value):
                try callback?(.success(value))
            case .failure:
                break
        }
        return self
    }
    
    /// Forwards any error to the provided callback.
    ///
    /// - Parameter callback: An optional closure to execute if the `Result` is a failure. This closure takes a `Result` of a new success value type and the original failure type.
    /// - Returns: The original `Result` instance.
    /// - Note: The callback will be executed only if the `Result` is a `.failure`. If the `Result` is a `.success`, the callback is not executed.
    @discardableResult
    func forwardError<T>(to callback: ((Result<T, Failure>) throws -> Void)?) rethrows -> Self {
        switch self {
            case .success:
                break
            case .failure(let error):
                try callback?(.failure(error))
        }
        return self
    }
    
}
