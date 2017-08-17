//
//  AppDelegate.swift
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

import Cocoa
import Alamofire
import Fabric
import Crashlytics

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet fileprivate var mainMenu: NSMenu!
    @IBOutlet private var exchangeMenuItem: NSMenuItem!
    @IBOutlet private var updateIntervalMenuItem: NSMenuItem!
    @IBOutlet fileprivate var currencyStartSeparator: NSMenuItem!
    @IBOutlet private var quitMenuItem: NSMenuItem!
    fileprivate var currencyMenuItems = [NSMenuItem]()
    
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let reachabilityManager = Alamofire.NetworkReachabilityManager()!
    
    private var currentExchange: Exchange! {
        didSet {
            TickerConfig.defaultExchangeSite = currentExchange.site
        }
    }
    
    // MARK: NSApplicationDelegate
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Start Fabric
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions": true])
        if let resourceURL = Bundle.main.url(forResource: "fabric", withExtension: "apikey") {
            do {
                var apiKey = try String.init(contentsOf: resourceURL, encoding: .utf8)
                apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                Crashlytics.start(withAPIKey: apiKey)
            } catch {
                print("Error loading Fabric API key: \(error)")
            }
        }
        
        // Listen to workspace status notifications
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWorkspaceWillSleep(notification:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWorkspaceDidWake(notification:)), name: NSWorkspace.didWakeNotification, object: nil)
        
        // Listen to network reachability status
        reachabilityManager.listenerQueue = DispatchQueue(label: "cointicker.reachability", qos: .utility, attributes: [.concurrent])
        reachabilityManager.listener = { [unowned self] status in
            if status == .reachable(.ethernetOrWiFi) || status == .reachable(.wwan) {
                self.currentExchange?.start()
            } else {
                self.currentExchange?.stop()
                self.updateMenuWithOfflineText()
            }
        }
        
        // Set the main menu
        statusItem.menu = mainMenu
        
        // Set up exchange sub-menu
        for exchangeSite in ExchangeSite.allValues {
            let item = NSMenuItem(title: exchangeSite.displayName, action: #selector(onSelectExchangeSite(sender:)), keyEquivalent: "")
            item.tag = exchangeSite.index
            exchangeMenuItem.submenu?.addItem(item)
        }
        
        // Load defaults
        currentExchange = Exchange.build(fromSite: TickerConfig.defaultExchangeSite, delegate: self)
        reachabilityManager.startListening()
        if !reachabilityManager.isReachable {
            updateMenuWithOfflineText()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        currentExchange?.stop()
    }
    
    // MARK: Notifications
    @objc private func onWorkspaceWillSleep(notification: Notification) {
        currentExchange?.stop()
    }
    
    @objc private func onWorkspaceDidWake(notification: Notification) {
        currentExchange?.start()
    }
    
    // MARK: UI Helpers
    fileprivate func updateMenuStates(forExchange exchange: Exchange) {
        exchangeMenuItem.submenu?.items.forEach({ $0.state = ($0.tag == exchange.site.index ? .onState : .offState) })
        updateIntervalMenuItem.submenu?.items.forEach({ $0.state = ($0.tag == TickerConfig.updateInterval ? .onState : .offState) })
        
        for menuItem in currencyMenuItems {
            let isSelected = (menuItem.tag == exchange.baseCurrency.index)
            menuItem.state = (isSelected ? .onState : .offState)
            if let subMenu = menuItem.submenu {
                subMenu.items.forEach({ $0.state = (isSelected && $0.tag == exchange.quoteCurrency.index ? .onState : .offState) })
            }
        }
        
        if let iconImage = exchange.baseCurrency.iconImage {
            iconImage.isTemplate = true
            statusItem.image = iconImage
        } else {
            statusItem.image = nil
        }
    }
    
    fileprivate func updateMenuText(_ text: String?) {
        DispatchQueue.main.async {
            self.statusItem.title = text
        }
    }
    
    private func updateMenuWithOfflineText() {
        updateMenuText(NSLocalizedString("menu.label.offline", comment: "Label to display when network connection fails"))
        if statusItem.image == nil {
            statusItem.image = Currency.btc.iconImage
        }
    }
    
    // MARK: UI Actions
    @objc private func onSelectExchangeSite(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem, let exchangeSite = ExchangeSite.build(fromIndex: menuItem.tag) {
            if exchangeSite != currentExchange.site {
                currentExchange.stop()
                currentExchange = Exchange.build(fromSite: exchangeSite, delegate: self)
                currentExchange.start()
                TrackingUtils.didSelectExchange(exchangeSite)
            }
        }
    }
    
    @IBAction private func onSelectUpdateInterval(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            TickerConfig.updateInterval = menuItem.tag
            currentExchange.reset()
            updateMenuStates(forExchange: currentExchange)
            TrackingUtils.didSelectUpdateInterval(TickerConfig.updateInterval)
        }
    }
    
    @objc fileprivate func onSelectBaseCurrency(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem, let baseCurrency = Currency.build(fromIndex: menuItem.tag) {
            currentExchange.baseCurrency = baseCurrency
            currentExchange.reset()
            updateMenuStates(forExchange: currentExchange)
            TrackingUtils.didSelectBaseCurrency(baseCurrency)
        }
    }
    
    @objc fileprivate func onSelectQuoteCurrency(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem, let parentMenuItem = menuItem.parent, let quoteCurrency = Currency.build(fromIndex: menuItem.tag), let baseCurrency = Currency.build(fromIndex: parentMenuItem.tag) {
            if baseCurrency != currentExchange.baseCurrency {
                TrackingUtils.didSelectBaseCurrency(baseCurrency)
            }
            
            currentExchange.baseCurrency = baseCurrency
            currentExchange.quoteCurrency = quoteCurrency
            currentExchange.reset()
            updateMenuStates(forExchange: currentExchange)
            TrackingUtils.didSelectQuoteCurrency(quoteCurrency)
        }
    }
    
    @IBAction private func onQuit(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }

}

extension AppDelegate: ExchangeDelegate {
    
    func exchange(_ exchange: Exchange, didLoadCurrencyMatrix currencyMatrix: CurrencyMatrix) {
        DispatchQueue.main.async {
            self.currencyMenuItems.forEach({ self.mainMenu.removeItem($0) })
            self.currencyMenuItems.removeAll()
            
            var itemIndex = self.mainMenu.index(of: self.currencyStartSeparator) + 1
            for baseCurrency in exchange.availableBaseCurrencies {
                let subMenu = NSMenu()
                currencyMatrix[baseCurrency]?.sorted(by: { $0.displayName < $1.displayName }).forEach({ (quoteCurrency) in
                    let item = NSMenuItem(title: quoteCurrency.displayName, action: #selector(self.onSelectQuoteCurrency(sender:)), keyEquivalent: "")
                    item.tag = quoteCurrency.index
                    if let smallIconImage = quoteCurrency.smallIconImage {
                        smallIconImage.isTemplate = quoteCurrency.isCrypto
                        item.image = smallIconImage
                    }
                    
                    subMenu.addItem(item)
                })
                
                let item = NSMenuItem(title: baseCurrency.displayName, action: #selector(self.onSelectBaseCurrency(sender:)), keyEquivalent: "")
                item.tag = baseCurrency.index
                if let smallIconImage = baseCurrency.smallIconImage {
                    smallIconImage.isTemplate = true
                    item.image = smallIconImage
                }
                
                item.submenu = subMenu
                self.mainMenu.insertItem(item, at: itemIndex)
                self.currencyMenuItems.append(item)
                
                itemIndex += 1
            }
            
            self.updateMenuStates(forExchange: exchange)
        }
    }
    
    func exchange(_ exchange: Exchange, didUpdatePrice price: Double?) {
        if let price = price {
            let currencyFormatter = NumberFormatter()
            currencyFormatter.numberStyle = .currency
            currencyFormatter.currencyCode = exchange.quoteCurrency.code
            currencyFormatter.currencySymbol = exchange.quoteCurrency.symbol
            currencyFormatter.maximumFractionDigits = (price < 1 ? 5 : 2)
            updateMenuText(currencyFormatter.string(for: price))
        } else {
            updateMenuText(NSLocalizedString("menu.label.loading", comment: "Label displayed when network requests are loading"))
        }
    }
    
}

