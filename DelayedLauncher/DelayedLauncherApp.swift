import SwiftUI
import AppKit
import CoreServices


// Controlla se Delayed Launcher è stato avviato manualmente con l’argomento speciale --startup
private let isExplicitStartupMode = CommandLine.arguments.contains("--startup")


// AppDelegate gestisce le operazioni che devono partire direttamente all’avvio dell’applicazione
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Memorizza se questa esecuzione deve funzionare in modalità automatica e invisibile
    private var isStartupMode = isExplicitStartupMode


    // Controlla l’Apple Event con cui macOS ha avviato l’app per riconoscere un vero avvio al login
    private func wasLaunchedAsLoginItem() -> Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent

        return event?.eventID == kAEOpenApplication &&
        event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }


    // Questa funzione viene eseguita nelle primissime fasi dell’avvio dell’applicazione
    func applicationWillFinishLaunching(_ notification: Notification) {

        // Riconosce sia il test con --startup sia un vero avvio automatico effettuato da macOS
        isStartupMode = isExplicitStartupMode || wasLaunchedAsLoginItem()

        // In modalità startup rende Delayed Launcher invisibile prima che macOS mostri l’interfaccia
        if isStartupMode {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }


    // Questa funzione viene eseguita automaticamente quando macOS ha terminato l’avvio dell’app
    func applicationDidFinishLaunching(_ notification: Notification) {

        // Ripete il controllo perché l’Apple Event di login può essere disponibile soltanto in questa fase
        isStartupMode = isStartupMode || wasLaunchedAsLoginItem()

        // Se Delayed Launcher è stato aperto normalmente non viene avviato nessun timer
        guard isStartupMode else {
            return
        }

        // Garantisce che Delayed Launcher resti un’applicazione accessoria durante l’avvio automatico
        NSApplication.shared.setActivationPolicy(.accessory)

        // Nasconde eventuali finestre create durante l’avvio automatico
        DispatchQueue.main.async {

            // Scorre tutte le finestre appartenenti a Delayed Launcher
            for window in NSApplication.shared.windows {

                // Nasconde la finestra senza chiudere l’applicazione
                window.orderOut(nil)
            }
        }

        // Avvia la logica automatica indipendentemente dalla finestra e dall’interfaccia grafica
        Task { @MainActor in

            // Carica le applicazioni e le impostazioni precedentemente salvate
            let store = AppStore()

            // Crea una copia della configurazione da utilizzare durante questo avvio
            let configuredApps = store.apps

            // Avvia contemporaneamente tutti i timer configurati
            await StartupScheduler.run(
                apps: configuredApps
            )
        }
    }
}


// @main indica a macOS che questa struttura rappresenta il punto di ingresso principale dell’applicazione
@main
struct DelayedLauncherApp: App {

    // Collega AppDelegate al ciclo di vita dell’applicazione SwiftUI
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate


    // Body crea normalmente la finestra principale quando l’app viene aperta manualmente
    var body: some Scene {

        // La finestra viene nascosta automaticamente da AppDelegate quando l’avvio proviene dal login
        WindowGroup {
            ContentView()
        }
    }
}
