//
//  Exchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/30/17.
//  Copyright © 2017 Alec Ananian.
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
//

import Foundation
import Cocoa
import Alamofire

enum ExchangeSite: Int {
    case bitstamp = 210
    case coincheck = 235
    case gdax = 240
    case korbit = 245
    case kraken = 250
    
    static let allValues = [bitstamp, coincheck, gdax, korbit, kraken]
    
    var index: Int {
        return self.rawValue
    }
    
    var displayName: String {
        switch self {
        case .bitstamp: return "Bitstamp"
        case .coincheck: return "Coincheck"
        case .gdax: return "GDAX"
        case .korbit: return "Korbit"
        case .kraken: return "Kraken"
        }
    }
    
    static func build(fromIndex index: Int) -> ExchangeSite? {
        return ExchangeSite(rawValue: index)
    }
}

protocol ExchangeDelegate {
    func exchange(_ exchange: Exchange, didUpdateAvailableCurrencyPairs availableCurrencyPairs: [CurrencyPair])
}

class Exchange {
    
    internal var site: ExchangeSite
    internal var delegate: ExchangeDelegate
    internal var apiRequests = [DataRequest]()
    internal var requestTimer: Timer?
    
    internal let apiResponseSerializer = DataRequest.jsonResponseSerializer()
    
    var availableCurrencyPairs = [CurrencyPair]()
    
    static func build(fromSite site: ExchangeSite, delegate: ExchangeDelegate) -> Exchange {
        switch site {
        case .bitstamp: return BitstampExchange(delegate: delegate)
        case .coincheck: return CoincheckExchange(delegate: delegate)
        case .gdax: return GDAXExchange(delegate: delegate)
        case .korbit: return KorbitExchange(delegate: delegate)
        case .kraken: return KrakenExchange(delegate: delegate)
        }
    }
    
    deinit {
        stop()
    }
    
    init(site: ExchangeSite, delegate: ExchangeDelegate) {
        self.site = site
        self.delegate = delegate
    }
    
    internal func apiResponseQueue(label: String = "responseQueue") -> DispatchQueue {
        return DispatchQueue(label: "cointicker.\(site.displayName)-api.\(label)", qos: .utility, attributes: [.concurrent])
    }
    
    internal func socketResponseQueue(label: String = "responseQueue") -> DispatchQueue {
        return DispatchQueue(label: "cointicker.bitstamp-socket.\(label)", qos: .utility, attributes: [.concurrent])
    }
    
    func load() {
        // Override
    }
    
    internal func fetch() {
        // Override
    }
    
    internal func stop() {
        apiRequests.forEach({ $0.cancel() })
        requestTimer?.invalidate()
        requestTimer = nil
    }
    
    func reset() {
        stop()
        fetch()
    }
    
    internal func startRequestTimer() {
        DispatchQueue.main.async {
            self.requestTimer = Timer.scheduledTimer(timeInterval: Double(TickerConfig.selectedUpdateInterval),
                                                     target: self,
                                                     selector: #selector(self.onRequestTimerFired(_:)),
                                                     userInfo: nil,
                                                     repeats: false)
        }
    }
    
    @objc internal func onRequestTimerFired(_ timer: Timer) {
        requestTimer?.invalidate()
        requestTimer = nil
        fetch()
    }

}
