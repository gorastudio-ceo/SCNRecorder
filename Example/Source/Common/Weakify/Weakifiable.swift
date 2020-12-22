//
//  Weakifiable.swift
//  Example
//
//  Created by Vladislav Grigoryev on 19.11.2020.
//  Copyright © 2020 GORA Studio. https://gora.studio
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
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

protocol Weakifiable: AnyObject { }

extension Weakifiable {

  typealias This = Self

  func weakify(
    _ closure: @escaping (Self) -> () -> Void
  ) -> () -> Void {
    Example.weakify(self, closure)
  }

  func weakify<Result>(
    _ closure: @escaping (Self) -> () -> Result
  ) -> () -> Result? {
    Example.weakify(self, closure)
  }

  func weakify<Parameter>(
    _ closure: @escaping (Self) -> (Parameter) -> Void
  ) -> (Parameter) -> Void {
    Example.weakify(self, closure)
  }

  func weakify<Parameter, Result>(
    _ closure: @escaping (Self) -> (Parameter) -> Result
  ) -> (Parameter) -> Result? {
    Example.weakify(self, closure)
  }
}

extension NSObject: Weakifiable { }
