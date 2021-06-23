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
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet private weak var mainMenu: NSMenu!
    @IBOutlet private weak var exchangeMenuItem: NSMenuItem!
    @IBOutlet private weak var updateIntervalMenuItem: NSMenuItem!
    @IBOutlet private weak var currencyStartSeparator: NSMenuItem!
    @IBOutlet private weak var showIconMenuItem: NSMenuItem!
    @IBOutlet private weak var quitMenuItem: NSMenuItem!
    private var currencyMenuItems = [NSMenuItem]()
    private var currencyFormatter = NumberFormatter()
    
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let reachabilityManager = Alamofire.NetworkReachabilityManager()!
    
    private var currentExchange: Exchange!
    
    // MARK: NSApplicationDelegate
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Start AppCenter
        if let resourceURL = Bundle.main.url(forResource: "appcenter", withExtension: "secret") {
            do {
                let appSecret = try String.init(contentsOf: resourceURL, encoding: .utf8)
                AppCenter.start(withAppSecret: appSecret.trimmingCharacters(in: .whitespacesAndNewlines), services: [
                    Analytics.self,
                    Crashes.self
                ])
            } catch {
                print("Error loading AppCenter app secret: \(error)")
            }
        }
        
        // Listen to workspace status notifications
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWorkspaceWillSleep(notification:)), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWorkspaceDidWake(notification:)), name: NSWorkspace.didWakeNotification, object: nil)
        
        // Set the main menu
        statusItem.menu = mainMenu
        
        // Load defaults
        currentExchange = TickerConfig.defaultExchange
        currentExchange.delegate = self
        exchangeMenuItem.submenu?.items.forEach({ $0.state = ($0.tag == currentExchange.site.rawValue ? .on : .off) })
        updateIntervalMenuItem.submenu?.items.forEach({ $0.state = ($0.tag == currentExchange.updateInterval ? .on : .off )})
        showIconMenuItem.state = (TickerConfig.showsIcon ? .on : .off)
        
        // Listen for network status
        let reachabilityQueue = DispatchQueue(label: "cointicker.reachability", qos: .utility, attributes: [.concurrent])
        reachabilityManager.startListening(onQueue: reachabilityQueue) { [weak self] status in
            if status == .reachable(.ethernetOrWiFi) || status == .reachable(.cellular) {
                self?.currentExchange?.load()
            } else {
                self?.currentExchange?.stop()
                self?.updateMenuWithOfflineText()
            }
        }
        
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
            let image = TickerConfig.LogoImage
            image.isTemplate = true
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
        
        if let baseCurrency = menuItem.parent?.representedObject as? Currency, let quoteCurrency = menuItem.representedObject as? Currency, currentExchange.selectedCurrencyPairs.count > 1 || currentExchange.selectedCurrencyPairs.first != CurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency) {
            // Reset exchange fetching
            currentExchange.toggleCurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency)
            
            // Update menus
            updateMenuItems()
            
            // Save new data
            TickerConfig.save(currentExchange)
        }
    }
    
    @IBAction private func onToggleShowIcon(sender: AnyObject) {
        let shouldShowMenuIcon = !TickerConfig.showsIcon
        showIconMenuItem.state = (shouldShowMenuIcon ? .on : .off)
        TickerConfig.showsIcon = shouldShowMenuIcon
        
        updateMenuIcon()
        updatePrices()
        
        TrackingUtils.didShowIcon(shouldShowMenuIcon)
    }
    
    @IBAction private func onQuit(sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }
    
    private func menuItem(forQuoteCurrency quoteCurrency: Currency) -> NSMenuItem {
        let item = NSMenuItem(title: quoteCurrency.displayName, action: #selector(self.onSelectQuoteCurrency(sender:)), keyEquivalent: "")
        item.representedObject = quoteCurrency
        let image = quoteCurrency.smallIconImage ?? TickerConfig.SmallLogoImage
        image.isTemplate = !quoteCurrency.isPhysical
        item.image = image
        return item
    }
    
    private func menuItem(forBaseCurrency baseCurrency: Currency) -> NSMenuItem {
        let item = NSMenuItem(title: baseCurrency.displayName, action: nil, keyEquivalent: "")
        item.representedObject = baseCurrency
        let image = baseCurrency.smallIconImage ?? TickerConfig.SmallLogoImage
        image.isTemplate = true
        item.image = image
        return item
    }
    
    fileprivate func updateMenuItems() {
        DispatchQueue.main.async {
            self.currencyMenuItems.forEach({ self.mainMenu.removeItem($0) })
            self.currencyMenuItems.removeAll()
            
            let indexOffset = self.mainMenu.index(of: self.currencyStartSeparator)
            var menuMapping = [String: NSMenuItem]()
            self.currentExchange.availableCurrencyPairs.forEach { currencyPair in
                let baseCurrency = currencyPair.baseCurrency
                let quoteCurrency = currencyPair.quoteCurrency
                if !baseCurrency.isPhysical {
                    let menuItem: NSMenuItem
                    if let savedMenuItem = menuMapping[baseCurrency.code] {
                        menuItem = savedMenuItem
                    } else {
                        menuItem = self.menuItem(forBaseCurrency: baseCurrency)
                        menuItem.state = (self.currentExchange.isCurrencyPairSelected(baseCurrency: baseCurrency) ? .on : .off)
                        menuItem.submenu = NSMenu()
                        menuMapping[baseCurrency.code] = menuItem
                        self.currencyMenuItems.append(menuItem)
                        self.mainMenu.insertItem(menuItem, at: menuMapping.count + indexOffset)
                    }
                    
                    let submenuItem = self.menuItem(forQuoteCurrency: quoteCurrency)
                    submenuItem.state = (self.currentExchange.isCurrencyPairSelected(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency) ? .on : .off)
                    menuItem.submenu!.addItem(submenuItem)
                }
            }
            
            self.updateMenuIcon()
            self.updatePrices()
        }
    }
    
    private func updateMenuIcon() {
        if TickerConfig.showsIcon {
            let iconImage: NSImage
            if self.currentExchange.isSingleBaseCurrencySelected, let image = self.currentExchange.selectedCurrencyPairs.first!.baseCurrency.iconImage {
                iconImage = image
            } else {
                iconImage = TickerConfig.LogoImage
            }
            
            iconImage.isTemplate = true
            self.statusItem.image = iconImage
        } else {
            self.statusItem.image = nil
        }
    }
    
    private func stringForPrice(_ price: Double, in quoteCurrency: Currency) -> String {
        guard price > 0 else {
            return NSLocalizedString("menu.label.loading", comment: "Label displayed when network requests are loading")
        }
        
        self.currencyFormatter.numberStyle = .currency
        self.currencyFormatter.currencyCode = quoteCurrency.code
        self.currencyFormatter.currencySymbol = quoteCurrency.symbol
        
        let numFractionDigits: Int
        if price < 0.001 {
            // Convert to satoshi if dealing with a small Bitcoin value
            if quoteCurrency.isBitcoin {
                // ex: 5,910 sat
                self.currencyFormatter.currencyCode = ""
                self.currencyFormatter.currencySymbol = ""
                self.currencyFormatter.minimumFractionDigits = 0
                self.currencyFormatter.maximumFractionDigits = 0
                return "\(self.currencyFormatter.string(for: price * 1e8)!) sat"
            } else {
                // ex: 0.0007330
                numFractionDigits = 7
            }
        } else if price < 0.01 {
            // ex: 0.009789
            numFractionDigits = 6
        } else if price < 0.1 {
            // ex: 0.04500
            numFractionDigits = 5
        } else if price < 1 {
            // ex: 0.1720
            numFractionDigits = 4
        } else if price < 10 {
            // ex: 9.506
            numFractionDigits = 3
        } else {
            // ex: 14,560.00
            numFractionDigits = 2
        }
        
        self.currencyFormatter.minimumFractionDigits = numFractionDigits
        self.currencyFormatter.maximumFractionDigits = numFractionDigits
        return self.currencyFormatter.string(for: price)!
    }
    
    fileprivate func updatePrices() {
        DispatchQueue.main.async {
            let priceStrings = self.currentExchange.selectedCurrencyPairs.map { currencyPair -> String in
                let price = self.currentExchange.price(for: currencyPair)
                let priceString = self.stringForPrice(price, in: currencyPair.quoteCurrency)
                if self.currentExchange.isSingleBaseCurrencySelected && TickerConfig.showsIcon {
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
