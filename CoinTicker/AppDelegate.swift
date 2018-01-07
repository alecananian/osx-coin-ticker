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
    @IBOutlet fileprivate var updateIntervalMenuItem: NSMenuItem!
    @IBOutlet private var currencyStartSeparator: NSMenuItem!
    @IBOutlet private var quitMenuItem: NSMenuItem!
    private var currencyMenuItems = [NSMenuItem]()
    private var currencyFormatter = NumberFormatter()
    
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let reachabilityManager = Alamofire.NetworkReachabilityManager()!
    
    private var currentExchange: Exchange!
    
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
                self.currentExchange?.load()
            } else {
                self.currentExchange?.stop()
                self.updateMenuWithOfflineText()
            }
        }
        
        // Set the main menu
        statusItem.menu = mainMenu
        
        // Load defaults
        currentExchange = TickerConfig.defaultExchange
        currentExchange.delegate = self
        exchangeMenuItem.submenu?.items.forEach({ $0.state = ($0.tag == currentExchange.site.rawValue ? .on : .off) })
        updateIntervalMenuItem.submenu?.items.forEach({ $0.state = ($0.tag == currentExchange.updateInterval ? .on : .off )})
        
        // Listen for network status
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
        currentExchange?.fetch()
    }
    
    // MARK: UI Helpers
    private func updateMenuWithOfflineText() {
        DispatchQueue.main.async {
            self.statusItem.title = NSLocalizedString("menu.label.offline", comment: "Label to display when network connection fails")
            let image = NSImage(named: NSImage.Name(rawValue: "CTLogo"))
            image?.isTemplate = true
            self.statusItem.image = image
        }
    }
    
    // MARK: UI Actions
    @IBAction private func onSelectExchangeSite(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem, let exchangeSite = ExchangeSite(rawValue: menuItem.tag) {
            if exchangeSite != currentExchange.site {
                // End current exchange
                currentExchange.stop()
                
                // Deselect all exchange menu items and select this one
                exchangeMenuItem.submenu?.items.forEach({ $0.state = .off })
                menuItem.state = .on
                
                // Remove all currency selections
                currencyMenuItems.forEach({ mainMenu.removeItem($0) })
                currencyMenuItems.removeAll()
                
                // Start new exchange
                let selectedCurrencyPairs = currentExchange.selectedCurrencyPairs
                currentExchange = exchangeSite.exchange(delegate: self)
                currentExchange.selectedCurrencyPairs = selectedCurrencyPairs
                currentExchange.load()
                
                // Save new data
                TickerConfig.save(currentExchange)
                
                // Track analytics
                TrackingUtils.didSelectExchange(menuItem.title)
            }
        }
    }
    
    @IBAction private func onSelectUpdateInterval(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem {
            // Reset exchange fetching
            currentExchange.updateInterval = menuItem.tag
            currentExchange.reset()
            
            // Deselect all update interval menu items and select this one
            updateIntervalMenuItem.submenu?.items.forEach({ $0.state = .off })
            menuItem.state = .on
            
            // Save new data
            TickerConfig.save(currentExchange)
        }
    }
    
    @objc private func onSelectQuoteCurrency(sender: AnyObject) {
        guard let menuItem = sender as? NSMenuItem else {
            return
        }
        
        if let baseCurrency = menuItem.parent?.representedObject as? Currency, let quoteCurrency = menuItem.representedObject as? Currency {
            // Reset exchange fetching
            currentExchange.toggleCurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency)
            currentExchange.reset()
            
            // Update menus
            updateMenuItems()
            
            // Save new data
            TickerConfig.save(currentExchange)
        }
    }
    
    @IBAction private func onQuit(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }
    
    private func menuItem(forQuoteCurrency quoteCurrency: Currency) -> NSMenuItem {
        let item = NSMenuItem(title: quoteCurrency.displayName, action: #selector(self.onSelectQuoteCurrency(sender:)), keyEquivalent: "")
        item.representedObject = quoteCurrency
        if let smallIconImage = quoteCurrency.smallIconImage {
            smallIconImage.isTemplate = quoteCurrency.isCrypto
            item.image = smallIconImage
        }
        
        return item
    }
    
    private func menuItem(forBaseCurrency baseCurrency: Currency) -> NSMenuItem {
        let item = NSMenuItem(title: baseCurrency.displayName, action: nil, keyEquivalent: "")
        item.representedObject = baseCurrency
        if let smallIconImage = baseCurrency.smallIconImage {
            smallIconImage.isTemplate = true
            item.image = smallIconImage
        }
        
        return item
    }
    
    fileprivate func updateMenuItems() {
        DispatchQueue.main.async {
            self.currencyMenuItems.forEach({ self.mainMenu.removeItem($0) })
            self.currencyMenuItems.removeAll()
            
            var menuItemMap = [Currency: NSMenuItem]()
            let indexOffset = self.mainMenu.index(of: self.currencyStartSeparator)
            self.currentExchange.availableCurrencyPairs.forEach({ (currencyPair) in
                let baseCurrency = currencyPair.baseCurrency
                let quoteCurrency = currencyPair.quoteCurrency
                var menuItem: NSMenuItem
                if let savedMenuItem = menuItemMap[baseCurrency] {
                    menuItem = savedMenuItem
                } else {
                    menuItem = self.menuItem(forBaseCurrency: baseCurrency)
                    menuItem.state = (self.currentExchange.isBaseCurrencySelected(baseCurrency) ? .on : .off)
                    menuItem.submenu = NSMenu()
                    menuItemMap[baseCurrency] = menuItem
                    self.currencyMenuItems.append(menuItem)
                    self.mainMenu.insertItem(menuItem, at: menuItemMap.count + indexOffset)
                }
                
                let submenuItem = self.menuItem(forQuoteCurrency: quoteCurrency)
                submenuItem.state = (self.currentExchange.isCurrencyPairSelected(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency) ? .on : .off)
                menuItem.submenu!.addItem(submenuItem)
            })
            
            var iconImage: NSImage? = nil
            if self.currentExchange.selectedCurrencyPairs.count == 1 {
                iconImage = self.currentExchange.selectedCurrencyPairs.first!.baseCurrency.iconImage
            } else {
                iconImage = NSImage(named: NSImage.Name(rawValue: "CTLogo"))
            }
            
            iconImage?.isTemplate = true
            self.statusItem.image = iconImage
            self.updatePrices()
        }
    }
    
    fileprivate func updatePrices() {
        DispatchQueue.main.async {
            let priceStrings = self.currentExchange.selectedCurrencyPairs.flatMap { (currencyPair) in
                let price = self.currentExchange.price(for: currencyPair)
                var priceString: String
                if price > 0 {
                    self.currencyFormatter.numberStyle = .currency
                    self.currencyFormatter.currencyCode = currencyPair.quoteCurrency.code
                    self.currencyFormatter.currencySymbol = currencyPair.quoteCurrency.symbol
                    self.currencyFormatter.maximumFractionDigits = (price < 1 ? 5 : 2)
                    priceString = self.currencyFormatter.string(for: price)!
                } else {
                    priceString = NSLocalizedString("menu.label.loading", comment: "Label displayed when network requests are loading")
                }
                
                if self.currentExchange.selectedCurrencyPairs.count == 1 {
                    return priceString
                }
                
                return "\(currencyPair.baseCurrency.code): \(priceString)"
            }
            
            self.statusItem.title = priceStrings.joined(separator: " • ")
        }
    }

}

extension AppDelegate: ExchangeDelegate {
    
    func exchange(_ exchange: Exchange, didUpdateAvailableCurrencyPairs availableCurrencyPairs: [CurrencyPair]) {
        updateMenuItems()
    }
    
    func exchangeDidUpdatePrices(_ exchange: Exchange) {
        updatePrices()
    }
    
}
