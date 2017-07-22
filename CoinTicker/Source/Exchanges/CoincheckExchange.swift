//
//  CoincheckExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 6/24/17.
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
import Alamofire

class CoincheckExchange: Exchange {
    
    private struct Constants {
        static let TickerAPIPath = "https://coincheck.com/api/ticker"
    }
    
    private let apiResponseQueue = DispatchQueue(label: "com.alecananian.cointicker.coincheck-api", qos: .utility, attributes: [.concurrent])
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .coincheck, delegate: delegate)
    }
    
    override func start() {
        super.start()
        
        currencyMatrix = [.btc: [.jpy]]
        delegate.exchange(self, didLoadCurrencyMatrix: currencyMatrix!)
        fetchPrice()
    }
    
    override func stop() {
        super.stop()
        
        requestTimer?.invalidate()
        requestTimer = nil
    }
    
    override internal func fetchPrice() {
        apiRequests.append(Alamofire.request(Constants.TickerAPIPath).response(queue: apiResponseQueue, responseSerializer: DataRequest.jsonResponseSerializer()) { [unowned self] (response) in
            if let price = (response.result.value as? JSONContainer)?["last"] as? Double {
                self.delegate.exchange(self, didUpdatePrice: price)
            }
            
            self.startRequestTimer()
        })
    }

}
