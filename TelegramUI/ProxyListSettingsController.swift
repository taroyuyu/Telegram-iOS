import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ProxySettingsControllerArguments {
    let toggleEnabled: (Bool) -> Void
    let addNewServer: () -> Void
    let activateServer: (ProxyServerSettings) -> Void
    let editServer: (ProxyServerSettings) -> Void
    let removeServer: (ProxyServerSettings) -> Void
    let setServerWithRevealedOptions: (ProxyServerSettings?, ProxyServerSettings?) -> Void
    let toggleUseForCalls: (Bool) -> Void
    
    init(toggleEnabled: @escaping (Bool) -> Void, addNewServer: @escaping () -> Void, activateServer: @escaping (ProxyServerSettings) -> Void, editServer: @escaping (ProxyServerSettings) -> Void, removeServer: @escaping (ProxyServerSettings) -> Void, setServerWithRevealedOptions: @escaping (ProxyServerSettings?, ProxyServerSettings?) -> Void, toggleUseForCalls: @escaping (Bool) -> Void) {
        self.toggleEnabled = toggleEnabled
        self.addNewServer = addNewServer
        self.activateServer = activateServer
        self.editServer = editServer
        self.removeServer = removeServer
        self.setServerWithRevealedOptions = setServerWithRevealedOptions
        self.toggleUseForCalls = toggleUseForCalls
    }
}

private enum ProxySettingsControllerSection: Int32 {
    case enabled
    case servers
    case calls
}

private enum ProxyServerAvailabilityStatus: Equatable {
    case checking
    case notAvailable
    case available(Int32)
}

private struct DisplayProxyServerStatus: Equatable {
    let activity: Bool
    let text: String
    let textActive: Bool
}

private enum ProxySettingsControllerEntryId: Equatable, Hashable {
    case index(Int)
    case server(String, Int32, String, String)
}

private enum ProxySettingsControllerEntry: ItemListNodeEntry {
    case enabled(PresentationTheme, String, Bool, Bool)
    case serversHeader(PresentationTheme, String)
    case addServer(PresentationTheme, String, Bool)
    case server(Int, PresentationTheme, PresentationStrings, ProxyServerSettings, Bool, DisplayProxyServerStatus, ProxySettingsServerItemEditing)
    case useForCalls(PresentationTheme, String, Bool)
    case useForCallsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .enabled:
                return ProxySettingsControllerSection.enabled.rawValue
            case .serversHeader, .addServer, .server:
                return ProxySettingsControllerSection.servers.rawValue
            case .useForCalls, .useForCallsInfo:
                return ProxySettingsControllerSection.calls.rawValue
        }
    }
    
    var stableId: ProxySettingsControllerEntryId {
        switch self {
            case .enabled:
                return .index(0)
            case .serversHeader:
                return .index(1)
            case .addServer:
                return .index(2)
            case let .server(_, _, _, settings, _, _, _):
                return .server(settings.host, settings.port, settings.username ?? "", settings.password ?? "")
            case .useForCalls:
                return .index(3)
            case .useForCallsInfo:
                return .index(4)
        }
    }
    
    static func ==(lhs: ProxySettingsControllerEntry, rhs: ProxySettingsControllerEntry) -> Bool {
        switch lhs {
            case let .enabled(lhsTheme, lhsText, lhsValue, lhsCreatesNew):
                if case let .enabled(rhsTheme, rhsText, rhsValue, rhsCreatesNew) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsCreatesNew == rhsCreatesNew {
                    return true
                } else {
                    return false
                }
            case let .serversHeader(lhsTheme, lhsText):
                if case let .serversHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addServer(lhsTheme, lhsText, lhsEditing):
                if case let .addServer(rhsTheme, rhsText, rhsEditing) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEditing == rhsEditing {
                    return true
                } else {
                    return false
                }
            case let .server(lhsIndex, lhsTheme, lhsStrings, lhsSettings, lhsActive, lhsStatus, lhsEditing):
                if case let .server(rhsIndex, rhsTheme, rhsStrings, rhsSettings, rhsActive, rhsStatus, rhsEditing) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsSettings == rhsSettings, lhsActive == rhsActive, lhsStatus == rhsStatus, lhsEditing == rhsEditing {
                    return true
                } else {
                    return false
                }
            case let .useForCalls(lhsTheme, lhsText, lhsValue):
                if case let .useForCalls(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .useForCallsInfo(lhsTheme, lhsText):
                if case let .useForCallsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ProxySettingsControllerEntry, rhs: ProxySettingsControllerEntry) -> Bool {
        switch lhs {
            case .enabled:
                switch rhs {
                    case .enabled:
                        return false
                    default:
                        return true
                }
            case .serversHeader:
                switch rhs {
                    case .enabled, .serversHeader:
                        return false
                    default:
                        return true
                }
            case .addServer:
                switch rhs {
                    case .enabled, .serversHeader, .addServer:
                        return false
                    default:
                        return true
                }
            case let .server(lhsIndex, _, _, _, _, _, _):
                switch rhs {
                    case .enabled, .serversHeader, .addServer:
                        return false
                    case let .server(rhsIndex, _, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return true
                }
            case .useForCalls:
                switch rhs {
                    case .enabled, .serversHeader, .addServer, .server, .useForCalls:
                        return false
                    default:
                        return true
                }
            case .useForCallsInfo:
                return false
        }
    }
    
    func item(_ arguments: ProxySettingsControllerArguments) -> ListViewItem {
        switch self {
            case let .enabled(theme, text, value, createsNew):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: !createsNew, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    if createsNew {
                        arguments.addNewServer()
                    } else {
                        arguments.toggleEnabled(value)
                    }
                })
            case let .serversHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .addServer(theme, text, editing):
                return ProxySettingsActionItem(theme: theme, title: text, sectionId: self.section, editing: editing, action: {
                    arguments.addNewServer()
                })
            case let .server(_, theme, strings, settings, active, status, editing):
                return ProxySettingsServerItem(theme: theme, strings: strings, server: settings, activity: status.activity, active: active, label: status.text, labelAccent: status.textActive, editing: editing, sectionId: self.section, action: {
                    arguments.activateServer(settings)
                }, infoAction: {
                    arguments.editServer(settings)
                }, setServerWithRevealedOptions: { lhs, rhs in
                    arguments.setServerWithRevealedOptions(lhs, rhs)
                }, removeServer: { _ in
                    arguments.removeServer(settings)
                })
            case let .useForCalls(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleUseForCalls(value)
                })
            case let .useForCallsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private func proxySettingsControllerEntries(presentationData: PresentationData, state: ProxySettingsControllerState, proxySettings: ProxySettings, statuses: [ProxyServerSettings: ProxyServerStatus], connectionStatus: ConnectionStatus) -> [ProxySettingsControllerEntry] {
    var entries: [ProxySettingsControllerEntry] = []

    entries.append(.enabled(presentationData.theme, presentationData.strings.ChatSettings_ConnectionType_UseProxy, proxySettings.enabled, proxySettings.servers.isEmpty))
    entries.append(.serversHeader(presentationData.theme, "SAVED PROXIES"))
    entries.append(.addServer(presentationData.theme, "Add Proxy", state.editing))
    var index = 0
    for server in proxySettings.servers {
        let status: ProxyServerStatus = statuses[server] ?? .checking
        let displayStatus: DisplayProxyServerStatus
        if proxySettings.enabled && server == proxySettings.activeServer {
            switch connectionStatus {
                case .waitingForNetwork:
                    displayStatus = DisplayProxyServerStatus(activity: true, text: "waiting for network", textActive: false)
                case .connecting, .updating:
                    displayStatus = DisplayProxyServerStatus(activity: true, text: "connecting", textActive: false)
                case .online:
                    displayStatus = DisplayProxyServerStatus(activity: false, text: "online", textActive: true)
            }
        } else {
            switch status {
                case .notAvailable:
                    displayStatus = DisplayProxyServerStatus(activity: false, text: "not available", textActive: false)
                case .checking:
                    displayStatus = DisplayProxyServerStatus(activity: false, text: "checking", textActive: false)
                case let .available(rtt):
                    let pingTime: Int = Int(rtt * 1000.0)
                    displayStatus = DisplayProxyServerStatus(activity: false, text: "available (ping: \(pingTime) ms)", textActive: false)
            }
        }
        entries.append(.server(index, presentationData.theme, presentationData.strings, server, server == proxySettings.activeServer, displayStatus, ProxySettingsServerItemEditing(editable: true, editing: state.editing, revealed: state.revealedServer == server)))
        index += 1
    }
    
    entries.append(.useForCalls(presentationData.theme, presentationData.strings.SocksProxySetup_UseForCalls, proxySettings.useForCalls))
    entries.append(.useForCallsInfo(presentationData.theme, presentationData.strings.SocksProxySetup_UseForCallsHelp))
    
    return entries
}

private struct ProxySettingsControllerState: Equatable {
    var editing: Bool = false
    var revealedServer: ProxyServerSettings? = nil
}

public func proxySettingsController(account: Account) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    let stateValue = Atomic(value: ProxySettingsControllerState())
    let statePromise = ValuePromise<ProxySettingsControllerState>(stateValue.with { $0 })
    let updateState: ((ProxySettingsControllerState) -> ProxySettingsControllerState) -> Void = { f in
        var changed = false
        let value = stateValue.modify { current in
            let updated = f(current)
            if updated != current {
                changed = true
            }
            return updated
        }
        if changed {
            statePromise.set(value)
        }
    }
    
    let arguments = ProxySettingsControllerArguments(toggleEnabled: { value in
        let _ = updateProxySettingsInteractively(postbox: account.postbox, network: account.network, { current in
            var current = current
            current.enabled = value
            return current
        }).start()
    }, addNewServer: {
        presentControllerImpl?(proxyServerSettingsController(account: account, currentSettings: nil), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, activateServer: { server in
        let _ = updateProxySettingsInteractively(postbox: account.postbox, network: account.network, { current in
            var current = current
            if current.activeServer != server {
                if let _ = current.servers.index(of: server) {
                    current.activeServer = server
                    current.enabled = true
                }
            }
            return current
        }).start()
    }, editServer: { server in
        presentControllerImpl?(proxyServerSettingsController(account: account, currentSettings: server), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, removeServer: { server in
        let _ = updateProxySettingsInteractively(postbox: account.postbox, network: account.network, { current in
            var current = current
            if let index = current.servers.index(of: server) {
                current.servers.remove(at: index)
                if current.activeServer == server {
                    current.activeServer = nil
                    current.enabled = false
                }
            }
            return current
        }).start()
    }, setServerWithRevealedOptions: { server, fromServer in
        updateState { state in
            var state = state
            if (server == nil && fromServer == state.revealedServer) || (server != nil && fromServer == nil) {
                state.revealedServer = server
            }
            return state
        }
    }, toggleUseForCalls: { value in
        let _ = updateProxySettingsInteractively(postbox: account.postbox, network: account.network, { current in
            var current = current
            current.useForCalls = value
            return current
        }).start()
    })
    
    let proxySettings = Promise<ProxySettings>()
    proxySettings.set(account.postbox.preferencesView(keys: [PreferencesKeys.proxySettings])
    |> map { preferencesView -> ProxySettings in
        if let value = preferencesView.values[PreferencesKeys.proxySettings] as? ProxySettings {
            return value
        } else {
            return ProxySettings.defaultSettings
        }
    })
    
    let statusesContext = ProxyServersStatuses(account: account, servers: proxySettings.get()
    |> map { proxySettings -> [ProxyServerSettings] in
        return proxySettings.servers
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get(), proxySettings.get(), statusesContext.statuses(), account.network.connectionStatus)
        |> map { presentationData, state, proxySettings, statuses, connectionStatus -> (ItemListControllerState, (ItemListNodeState<ProxySettingsControllerEntry>, ProxySettingsControllerEntry.ItemGenerationArguments)) in
            let rightNavigationButton: ItemListNavigationButton?
            if proxySettings.servers.isEmpty {
                rightNavigationButton = nil
            } else if state.editing {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    updateState { state in
                        var state = state
                        state.editing = false
                        return state
                    }
                })
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    updateState { state in
                        var state = state
                        state.editing = true
                        return state
                    }
                })
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.SocksProxySetup_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(entries: proxySettingsControllerEntries(presentationData: presentationData, state: state, proxySettings: proxySettings, statuses: statuses, connectionStatus: connectionStatus), style: .blocks)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(account: account, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    controller.reorderEntry = { fromIndex, toIndex, entries in
        let fromEntry = entries[fromIndex]
        guard case let .server(_, _, _, fromServer, _, _, _) = fromEntry else {
            return
        }
        var referenceServer: ProxyServerSettings?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
                case let .server(_, _, _, toServer, _, _, _):
                    referenceServer = toServer
                default:
                    if entries[toIndex] < fromEntry {
                        beforeAll = true
                    } else {
                        afterAll = true
                    }
            }
        } else {
            afterAll = true
        }

        let _ = updateProxySettingsInteractively(postbox: account.postbox, network: account.network, { current in
            var current = current
            if let index = current.servers.index(of: fromServer) {
                current.servers.remove(at: index)
            }
            if let referenceServer = referenceServer {
                var inserted = false
                for i in 0 ..< current.servers.count {
                    if current.servers[i] == referenceServer {
                        if fromIndex < toIndex {
                            current.servers.insert(fromServer, at: i + 1)
                        } else {
                            current.servers.insert(fromServer, at: i)
                        }
                        inserted = true
                        break
                    }
                }
                if !inserted {
                    current.servers.append(fromServer)
                }
            } else if beforeAll {
                current.servers.insert(fromServer, at: 0)
            } else if afterAll {
                current.servers.append(fromServer)
            }
            return current
        }).start()
    }
    return controller
}
