//
//  TickerConfig.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/30/17.
//  Copyright © 2017 Alec Ananian. All rights reserved.
//

import Foundation

class TickerConfig {
    
    static var currentExchange: Exchange? {
        didSet {
            oldValue?.stop()
            currentExchange?.start()
        }
    }
    
    static var currentCurrency = Currency.usd {
        didSet {
            currentExchange?.reset()
        }
    }
    
    static var currentCryptoCurrency = CryptoCurrency.bitcoin {
        didSet {
            currentExchange?.reset()
        }
    }

}
