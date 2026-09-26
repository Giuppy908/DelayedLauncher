import SwiftUI

import AppKit

import UniformTypeIdentifiers

import Combine
import ServiceManagement





// Questa struttura rappresenta una singola applicazione gestita da Delayed Launcher

struct LaunchApp: Identifiable, Codable, Equatable, Sendable {



    // Identificatore univoco utilizzato da SwiftUI per distinguere ogni applicazione

    var id: UUID = UUID()



    // Nome dell'applicazione mostrato nell'interfaccia

    var name: String



    // Percorso completo del file .app presente sul Mac

    var path: String



    // Ritardo espresso in secondi prima dell'avvio dell'applicazione

    var delay: Int



    // Stabilisce se l'applicazione deve essere avviata oppure ignorata

    var isEnabled: Bool

}





// Questa enumerazione rappresenta le modalità disponibili per ordinare le applicazioni

enum SortMode: String, CaseIterable, Identifiable {



    // Ordina le applicazioni alfabeticamente dalla A alla Z

    case nameAscending



    // Ordina le applicazioni alfabeticamente dalla Z alla A

    case nameDescending



    // Permette a SwiftUI di distinguere ogni modalità di ordinamento

    var id: String {

        rawValue

    }

}





// Questa classe gestisce l'elenco delle applicazioni e il salvataggio delle impostazioni

class AppStore: ObservableObject {



    // Published permette a SwiftUI di aggiornare automaticamente l'interfaccia quando la lista cambia

    @Published var apps: [LaunchApp] = [] {



        // Ogni modifica alla lista viene salvata automaticamente

        didSet {

            saveApps()

        }

    }



    // Chiave utilizzata per salvare i dati nelle preferenze locali dell'applicazione

    private let storageKey = "savedLaunchApps"





    // Il costruttore viene eseguito quando AppStore viene creato

    init() {



        // Carica le applicazioni salvate durante un utilizzo precedente

        loadApps()

    }





    // Salva l'intero elenco delle applicazioni utilizzando UserDefaults

    private func saveApps() {



        // JSONEncoder trasforma l'array Swift in dati che possono essere memorizzati

        guard let encodedData = try? JSONEncoder().encode(apps) else {

            return

        }



        // I dati codificati vengono salvati nelle preferenze locali dell'applicazione

        UserDefaults.standard.set(encodedData, forKey: storageKey)

    }





    // Recupera l'elenco delle applicazioni precedentemente salvato

    private func loadApps() {



        // Recupera i dati salvati da UserDefaults

        guard let savedData = UserDefaults.standard.data(forKey: storageKey) else {

            return

        }



        // JSONDecoder riconverte i dati salvati nell'array originale di LaunchApp

        guard let decodedApps = try? JSONDecoder().decode([LaunchApp].self, from: savedData) else {

            return

        }



        // Assegna le applicazioni recuperate alla lista utilizzata dall'interfaccia

        apps = decodedApps

    }





    // Aggiunge una nuova applicazione alla lista

    func addApp(name: String, path: String) {



        // Evita che la stessa applicazione venga aggiunta più volte

        guard !apps.contains(where: { $0.path == path }) else {

            return

        }



        // Crea una nuova applicazione con 10 secondi di ritardo come valore iniziale

        let newApp = LaunchApp(

            name: name,

            path: path,

            delay: 10,

            isEnabled: true

        )



        // Inserisce la nuova applicazione nell'elenco

        apps.append(newApp)

    }





    // Rimuove un'applicazione utilizzando il suo identificatore univoco

    func removeApp(id: UUID) {



        // Elimina dalla lista l'elemento che possiede l'identificatore ricevuto

        apps.removeAll { $0.id == id }

    }





    // Ordina alfabeticamente le applicazioni utilizzando il loro nome

    func sortAppsByName(ascending: Bool) {



        // Decide se utilizzare l'ordinamento crescente oppure decrescente

        if ascending {



            // Ordina dalla A alla Z ignorando differenze tra maiuscole e minuscole

            apps.sort {

                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending

            }



        } else {



            // Ordina dalla Z alla A ignorando differenze tra maiuscole e minuscole

            apps.sort {

                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending

            }

        }

    }

}





// Questa struttura contiene la logica utilizzata durante l'avvio automatico del Mac

struct StartupScheduler {



    // Esegue contemporaneamente tutti i timer delle applicazioni abilitate

    static func run(apps: [LaunchApp]) async {



        // Considera esclusivamente le applicazioni abilitate dall'utente

        let enabledApps = apps.filter { $0.isEnabled }



        // TaskGroup permette a ogni applicazione di avere un timer indipendente

        await withTaskGroup(of: Void.self) { group in



            // Crea un'attività separata per ogni applicazione abilitata

            for app in enabledApps {



                group.addTask {



                    // Converte il ritardo espresso in secondi nel formato utilizzato da Task.sleep

                    let nanoseconds = UInt64(app.delay) * 1_000_000_000



                    // Attende esclusivamente il ritardo configurato per questa applicazione

                    try? await Task.sleep(nanoseconds: nanoseconds)



                    // Interrompe il lavoro se il task è stato annullato

                    guard !Task.isCancelled else {

                        return

                    }



                    // Controlla e avvia l'applicazione sul thread principale di macOS

                    await launchApplicationIfNeeded(app)

                }

            }

        }



        // Attende qualche secondo dopo il completamento di tutti i timer

        try? await Task.sleep(nanoseconds: 3_000_000_000)



        // Chiude Delayed Launcher perché il lavoro automatico è terminato

        await MainActor.run {

            NSApplication.shared.terminate(nil)

        }

    }





    // Controlla se l'applicazione è già aperta e la avvia soltanto quando necessario

    @MainActor

    private static func launchApplicationIfNeeded(_ app: LaunchApp) async {



        // Non esegue alcuna operazione se l'applicazione risulta già in esecuzione

        guard !isApplicationRunning(app) else {

            return

        }



        // Converte il percorso salvato nell'URL richiesto dalle API di macOS

        let applicationURL = URL(fileURLWithPath: app.path)



        // Verifica che l'applicazione esista ancora nella posizione salvata

        guard FileManager.default.fileExists(atPath: applicationURL.path) else {

            return

        }



        // Crea la configurazione utilizzata da macOS per aprire l'applicazione

        let configuration = NSWorkspace.OpenConfiguration()



        // Evita di portare automaticamente l'applicazione appena aperta in primo piano

        configuration.activates = false



        // Evita di creare intenzionalmente una nuova istanza di un'applicazione già esistente

        configuration.createsNewApplicationInstance = false



        // Evita di aggiungere l'apertura automatica all'elenco degli elementi recenti

        configuration.addsToRecentItems = false



        // Attende che macOS abbia completato la richiesta di apertura prima di terminare il task

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in



            // Richiede a macOS di aprire l'applicazione utilizzando la configurazione definita

            NSWorkspace.shared.openApplication(

                at: applicationURL,

                configuration: configuration

            ) { _, _ in



                // Comunica al task asincrono che la richiesta di apertura è terminata

                continuation.resume()

            }

        }

    }





    // Verifica se una determinata applicazione è già attualmente in esecuzione

    @MainActor

    private static func isApplicationRunning(_ app: LaunchApp) -> Bool {



        // Prova prima a recuperare il Bundle Identifier dell'applicazione

        if let bundleIdentifier = Bundle(url: URL(fileURLWithPath: app.path))?.bundleIdentifier {



            // Cerca eventuali processi già aperti che utilizzano lo stesso Bundle Identifier

            let runningApplications = NSRunningApplication.runningApplications(

                withBundleIdentifier: bundleIdentifier

            )



            // Se esiste almeno un processo corrispondente l'applicazione è già aperta

            if !runningApplications.isEmpty {

                return true

            }

        }



        // Prepara il percorso dell'applicazione configurata in forma standardizzata

        let configuredURL = URL(fileURLWithPath: app.path).standardizedFileURL



        // Utilizza il percorso come controllo aggiuntivo nel caso in cui il Bundle Identifier non sia disponibile

        return NSWorkspace.shared.runningApplications.contains { runningApplication in



            // Ignora i processi che non espongono il percorso della propria applicazione

            guard let runningURL = runningApplication.bundleURL?.standardizedFileURL else {

                return false

            }



            // Considera aperta l'applicazione quando il percorso corrisponde

            return runningURL == configuredURL

        }

    }

}





// Questa classe gestisce l’avvio automatico di Delayed Launcher al login tramite l’API nativa di macOS
@MainActor
final class LoginItemManager: ObservableObject {

    // Published permette all’interfaccia di aggiornarsi quando cambia lo stato dell’avvio al login
    @Published private(set) var isEnabled: Bool = false

    // Indica se macOS richiede un’approvazione manuale nelle Impostazioni di Sistema
    @Published private(set) var requiresApproval: Bool = false

    // Contiene un eventuale messaggio di errore da mostrare all’utente
    @Published var errorMessage: String?

    // Utilizza il servizio nativo associato direttamente all’app principale
    private let service = SMAppService.mainApp


    // Il costruttore recupera immediatamente lo stato attuale del login item
    init() {
        refreshStatus()
    }


    // Aggiorna lo stato leggendo direttamente la configurazione gestita da macOS
    func refreshStatus() {
        switch service.status {
        case .enabled:
            isEnabled = true
            requiresApproval = false

        case .requiresApproval:
            isEnabled = true
            requiresApproval = true

        case .notRegistered, .notFound:
            isEnabled = false
            requiresApproval = false

        @unknown default:
            isEnabled = false
            requiresApproval = false
        }
    }


    // Attiva o disattiva l’avvio automatico senza creare script o LaunchAgent esterni
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }

            // Rilegge lo stato effettivo dopo la richiesta
            refreshStatus()

        } catch {
            // Mantiene l’interfaccia sincronizzata anche quando la richiesta non riesce
            refreshStatus()
            errorMessage = error.localizedDescription
        }
    }


    // Apre direttamente la sezione di macOS dedicata agli elementi di login quando serve un’approvazione
    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}


// ContentView rappresenta la schermata principale di Delayed Launcher

struct ContentView: View {



    // StateObject mantiene AppStore in memoria per tutta la durata della schermata

    @StateObject private var store = AppStore()

    // StateObject mantiene sincronizzato lo stato dell’avvio automatico al login
    @StateObject private var loginItemManager = LoginItemManager()

    // State controlla la visualizzazione dell’avviso relativo al login item
    @State private var showLoginItemAlert = false



    // AppStorage salva automaticamente la modalità di ordinamento scelta dall'utente

    @AppStorage("selectedSortMode") private var sortModeRawValue = SortMode.nameAscending.rawValue



    // State conserva temporaneamente il testo scritto nei campi del ritardo

    @State private var delayTexts: [UUID: String] = [:]



    // State contiene gli identificatori delle applicazioni che risultano attualmente aperte

    @State private var runningAppIDs: Set<UUID> = []



    // FocusState permette di sapere quale campo del ritardo possiede attualmente il cursore

    @FocusState private var focusedDelayAppID: UUID?





    // Restituisce la modalità di ordinamento attualmente selezionata

    private var sortMode: SortMode {

        SortMode(rawValue: sortModeRawValue) ?? .nameAscending

    }





    // Crea un Binding utilizzato dal controllo grafico per modificare l'ordinamento

    private var sortModeBinding: Binding<SortMode> {



        Binding(

            get: {

                sortMode

            },

            set: { newMode in



                // Salva la nuova modalità scelta

                sortModeRawValue = newMode.rawValue



                // Riordina immediatamente l'elenco delle applicazioni

                store.sortAppsByName(

                    ascending: newMode == .nameAscending

                )

            }

        )

    }





    // Body descrive l'intera interfaccia grafica della finestra principale

    var body: some View {



        ZStack {



            VStack(alignment: .leading, spacing: 20) {



                // Titolo principale dell'applicazione

                Text("Delayed Launcher")

                    .font(.largeTitle)

                    .fontWeight(.bold)



                // Descrizione sintetica dello scopo dell'applicazione

                Text("Gestisci quali applicazioni devono avviarsi automaticamente dopo il login e con quale ritardo")

                    .font(.body)

                    .foregroundStyle(.secondary)



                // Separa visivamente l'intestazione dall'elenco delle applicazioni

                Divider()





                // Se non sono presenti applicazioni viene mostrato un messaggio informativo

                if store.apps.isEmpty {



                    VStack(spacing: 12) {



                        // Icona mostrata quando la lista è vuota

                        Image(systemName: "app.badge.plus")

                            .font(.system(size: 40))

                            .foregroundStyle(.secondary)



                        // Messaggio principale

                        Text("Nessuna applicazione configurata")

                            .font(.title3)

                            .fontWeight(.medium)



                        // Spiegazione per l'utente

                        Text("Premi il pulsante in basso per scegliere la prima applicazione")

                            .foregroundStyle(.secondary)

                    }

                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                }



                else {



                    // ScrollView permette di scorrere l'elenco se vengono aggiunte molte applicazioni

                    ScrollView {



                        VStack(spacing: 8) {



                            // ForEach crea automaticamente una riga per ogni applicazione presente nello store

                            ForEach($store.apps) { $app in



                                // Ogni riga viene separata visivamente dalle altre

                                VStack(spacing: 8) {



                                    HStack(spacing: 14) {



                                        // Permette di abilitare o disabilitare l'avvio dell'applicazione

                                        Toggle("", isOn: $app.isEnabled)

                                            .labelsHidden()



                                        // Mostra l'icona originale dell'applicazione selezionata

                                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))

                                            .resizable()

                                            .scaledToFit()

                                            .frame(width: 32, height: 32)



                                        // Mostra il nome, lo stato e il percorso dell'applicazione

                                        VStack(alignment: .leading, spacing: 3) {



                                            HStack(spacing: 6) {



                                                // Il piccolo indicatore mostra se l'applicazione è attualmente aperta

                                                Circle()

                                                    .fill(

                                                        runningAppIDs.contains(app.id)

                                                        ? Color.green

                                                        : Color.secondary.opacity(0.35)

                                                    )

                                                    .frame(width: 7, height: 7)

                                                    .help(

                                                        runningAppIDs.contains(app.id)

                                                        ? "Applicazione in esecuzione"

                                                        : "Applicazione non in esecuzione"

                                                    )



                                                // Nome principale dell'applicazione

                                                Text(app.name)

                                                    .fontWeight(.medium)

                                            }



                                            // Percorso del file .app

                                            Text(app.path)

                                                .font(.caption)

                                                .foregroundStyle(.secondary)

                                                .lineLimit(1)

                                                .truncationMode(.middle)

                                        }



                                        // Occupa lo spazio disponibile e spinge i controlli verso destra

                                        Spacer()



                                        // Etichetta del controllo relativo al ritardo

                                        Text("Ritardo")

                                            .foregroundStyle(.secondary)





                                        // Campo di testo che accetta esclusivamente caratteri numerici

                                        TextField(

                                            "",

                                            text: delayTextBinding(for: $app)

                                        )

                                        .textFieldStyle(.roundedBorder)

                                        .multilineTextAlignment(.center)

                                        .monospacedDigit()

                                        .frame(width: 60)

                                        .focused(

                                            $focusedDelayAppID,

                                            equals: app.id

                                        )





                                        // I due pulsanti permettono di modificare il ritardo senza utilizzare la tastiera

                                        VStack(spacing: 3) {



                                            // Aumenta il ritardo di un secondo

                                            Button {

                                                changeDelay(

                                                    for: $app,

                                                    by: 1

                                                )

                                            } label: {

                                                Image(systemName: "chevron.up")

                                                    .font(.system(size: 10, weight: .medium))

                                                    .frame(width: 7, height: 10)

                                            }

                                            .buttonStyle(.bordered)

                                            .controlSize(.mini)

                                            .buttonRepeatBehavior(.enabled)

                                            .disabled(app.delay >= 100)

                                            .help("Aumenta il ritardo")





                                            // Diminuisce il ritardo di un secondo

                                            Button {

                                                changeDelay(

                                                    for: $app,

                                                    by: -1

                                                )

                                            } label: {

                                                Image(systemName: "chevron.down")

                                                    .font(.system(size: 10, weight: .medium))

                                                    .frame(width: 7, height: 10)

                                            }

                                            .buttonStyle(.bordered)

                                            .controlSize(.mini)

                                            .buttonRepeatBehavior(.enabled)

                                            .disabled(app.delay <= 1)

                                            .help("Diminuisci il ritardo")

                                        }





                                        // Mostra l'unità di misura accanto al campo numerico

                                        Text("s")

                                            .foregroundStyle(.secondary)





                                        // Pulsante utilizzato per eliminare l'applicazione dalla configurazione

                                        Button {



                                            // Elimina anche l'eventuale testo temporaneo associato all'applicazione

                                            delayTexts.removeValue(forKey: app.id)



                                            // Rimuove l'applicazione selezionata

                                            store.removeApp(id: app.id)



                                            // Aggiorna gli indicatori dopo la rimozione

                                            refreshRunningApplications()



                                        } label: {



                                            // Utilizza l'icona standard del cestino di macOS

                                            Image(systemName: "trash")

                                        }

                                        .buttonStyle(.borderless)

                                        .help("Rimuovi applicazione")

                                    }



                                    // Crea una linea sottile tra una riga e quella successiva

                                    Divider()

                                }

                            }

                        }

                    }

                }





                // Separa l'elenco dai controlli presenti nella parte inferiore

                Divider()





                HStack {



                    // Questo pulsante apre il selettore standard di macOS per scegliere una nuova applicazione

                    Button {



                        // Rimuove prima il cursore da un eventuale campo del ritardo

                        dismissDelayFocus()



                        // Richiama la funzione che mostra la finestra di selezione

                        selectApplication()



                    } label: {



                        // Label combina automaticamente icona e testo

                        Label("Aggiungi applicazione", systemImage: "plus")

                    }

                    .keyboardShortcut("n", modifiers: [.command])


                    // Crea una piccola separazione visiva tra l’aggiunta delle app e l’avvio automatico
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 4)


                    // Permette di attivare o disattivare l’avvio automatico direttamente dall’app
                    Toggle(
                        "Avvia al login",
                        isOn: Binding(
                            get: {
                                loginItemManager.isEnabled
                            },
                            set: { newValue in
                                loginItemManager.setEnabled(newValue)

                                // Mostra un avviso solo se macOS richiede un’approvazione aggiuntiva
                                if loginItemManager.requiresApproval || loginItemManager.errorMessage != nil {
                                    showLoginItemAlert = true
                                }
                            }
                        )
                    )
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .fixedSize()
                    .help(
                        loginItemManager.requiresApproval
                        ? "macOS richiede l’approvazione dell’avvio al login"
                        : "Avvia Delayed Launcher automaticamente dopo il login"
                    )





                    // Occupa tutto lo spazio disponibile verso destra

                    Spacer()





                    // Mostra quante applicazioni sono attualmente configurate

                    Text("\(store.apps.count) applicazioni")

                        .foregroundStyle(.secondary)





                    // Crea una piccola separazione visiva tra il contatore e l'ordinamento

                    Divider()

                        .frame(height: 20)

                        .padding(.horizontal, 4)





                    // Descrive chiaramente la funzione del controllo successivo

                    Text("Ordina per nome")

                        .foregroundStyle(.secondary)





                    // Il controllo segmentato mostra in modo evidente quale ordinamento è attivo

                    Picker(

                        "Ordina per nome",

                        selection: sortModeBinding

                    ) {



                        // Ordine alfabetico crescente

                        Text("A → Z")

                            .tag(SortMode.nameAscending)



                        // Ordine alfabetico decrescente

                        Text("Z → A")

                            .tag(SortMode.nameDescending)

                    }

                    .pickerStyle(.segmented)

                    .labelsHidden()

                    .frame(width: 130)

                }

            }



            // Rende cliccabile anche lo spazio vuoto dell'interfaccia per rimuovere il focus dai campi numerici

            .contentShape(Rectangle())



            // Quando l'utente clicca in una zona vuota viene confermato il valore corrente e rimosso il cursore

            .onTapGesture {

                dismissDelayFocus()

            }



            .padding(30)

        }



        // Imposta una dimensione minima adeguata per la finestra dell'applicazione

        .frame(minWidth: 750, minHeight: 500)



        // Gestisce il cambio di focus tra i diversi campi del ritardo

        .onChange(of: focusedDelayAppID) { oldValue, newValue in



            // Normalizza il valore del campo che ha appena perso il focus

            if let oldValue, oldValue != newValue {

                normalizeDelay(for: oldValue)

            }

        }



        // Permette di uscire dal campo numerico premendo il tasto Esc

        .onExitCommand {

            dismissDelayFocus()

        }



        // Aggiorna lo stato quando macOS comunica l'apertura di un'applicazione
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didLaunchApplicationNotification
            )
        ) { _ in

            // Esegue un nuovo controllo dopo che macOS ha completato l'aggiornamento dei processi
            refreshRunningApplicationsAfterWorkspaceEvent()
        }


        // Aggiorna lo stato quando macOS comunica la chiusura di un'applicazione
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didTerminateApplicationNotification
            )
        ) { _ in

            // Esegue un nuovo controllo dopo che macOS ha completato l'aggiornamento dei processi
            refreshRunningApplicationsAfterWorkspaceEvent()
        }


        // Esegue anche un controllo periodico per mantenere sempre aggiornato lo stato delle applicazioni
        .task {

            // Continua a controllare finché ContentView rimane attiva
            while !Task.isCancelled {

                // Aggiorna lo stato reale di tutte le applicazioni configurate
                refreshRunningApplications()

                // Attende un secondo prima del controllo successivo
                try? await Task.sleep(
                    nanoseconds: 1_000_000_000
                )
            }
        }


        // Aggiorna lo stato del login item quando l’app torna in primo piano dopo le Impostazioni di Sistema
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            loginItemManager.refreshStatus()
        }

        // Mostra eventuali problemi o richieste di approvazione senza modificare il resto dell’interfaccia
        .alert("Avvio al login", isPresented: $showLoginItemAlert) {
            if loginItemManager.requiresApproval {
                Button("Apri Impostazioni") {
                    loginItemManager.openLoginItemsSettings()
                }

                Button("Chiudi", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) {
                    loginItemManager.errorMessage = nil
                }
            }
        } message: {
            if loginItemManager.requiresApproval {
                Text("macOS richiede l’approvazione dell’avvio automatico nelle Impostazioni di Sistema")
            } else {
                Text(loginItemManager.errorMessage ?? "Non è stato possibile aggiornare l’avvio al login")
            }
        }


        // Configura i valori iniziali quando la schermata viene mostrata

        .onAppear {



            // Riordina le applicazioni in base alla preferenza salvata

            store.sortAppsByName(

                ascending: sortMode == .nameAscending

            )



            // Prepara il testo iniziale mostrato nei campi dei secondi

            syncDelayTexts()



            // Controlla quali applicazioni risultano già aperte

            refreshRunningApplications()

        }

    }





    // Crea il collegamento tra il testo del campo e il valore numerico del ritardo

    private func delayTextBinding(for app: Binding<LaunchApp>) -> Binding<String> {



        Binding(

            get: {



                // Utilizza il testo temporaneo se presente oppure il valore numerico salvato

                delayTexts[app.wrappedValue.id] ?? String(app.wrappedValue.delay)

            },

            set: { newValue in



                // Conserva esclusivamente i caratteri numerici ignorando qualsiasi lettera o simbolo

                let numericValue = newValue.filter { $0.isNumber }



                // Se non rimane nessun numero viene immediatamente ripristinato il valore minimo consentito

                if numericValue.isEmpty {

                    app.wrappedValue.delay = 1

                    delayTexts[app.wrappedValue.id] = "1"

                    return

                }



                // Converte il testo numerico in un numero intero

                guard let number = Int(numericValue) else {

                    return

                }



                // Se il valore è inferiore a 1 viene immediatamente corretto a 1

                if number < 1 {

                    app.wrappedValue.delay = 1

                    delayTexts[app.wrappedValue.id] = "1"

                    return

                }



                // Se il valore è superiore a 100 viene immediatamente corretto a 100

                if number > 100 {

                    app.wrappedValue.delay = 100

                    delayTexts[app.wrappedValue.id] = "100"

                    return

                }



                // Aggiorna il valore reale del ritardo

                app.wrappedValue.delay = number



                // Mantiene nel campo soltanto la rappresentazione numerica valida

                delayTexts[app.wrappedValue.id] = String(number)

            }

        )

    }





    // Aumenta o diminuisce il ritardo utilizzando i due pulsanti accanto al campo

    private func changeDelay(for app: Binding<LaunchApp>, by amount: Int) {



        // Calcola il nuovo valore mantenendolo sempre tra 1 e 100

        let newValue = min(

            100,

            max(

                1,

                app.wrappedValue.delay + amount

            )

        )



        // Aggiorna il valore salvato nell'applicazione

        app.wrappedValue.delay = newValue



        // Aggiorna anche il testo visibile nel campo

        delayTexts[app.wrappedValue.id] = String(newValue)

    }





    // Normalizza il contenuto di un campo quando l'utente termina la modifica

    private func normalizeDelay(for id: UUID) {



        // Cerca l'applicazione corrispondente all'identificatore ricevuto

        guard let index = store.apps.firstIndex(where: { $0.id == id }) else {

            return

        }



        // Recupera il testo temporaneo oppure utilizza il valore già salvato

        let currentText = delayTexts[id] ?? String(store.apps[index].delay)



        // Converte il testo in numero utilizzando il valore precedente se il campo è vuoto

        let parsedValue = Int(currentText) ?? store.apps[index].delay



        // Mantiene il valore finale sempre compreso tra 1 e 100

        let normalizedValue = min(

            100,

            max(

                1,

                parsedValue

            )

        )



        // Salva il valore normalizzato nell'applicazione

        store.apps[index].delay = normalizedValue



        // Aggiorna il testo mostrato all'utente

        delayTexts[id] = String(normalizedValue)

    }





    // Rimuove il cursore dal campo attivo e conferma il valore attualmente inserito

    private func dismissDelayFocus() {



        // Normalizza prima il campo che possiede attualmente il focus

        if let focusedDelayAppID {

            normalizeDelay(for: focusedDelayAppID)

        }



        // Nessun campo numerico rimane selezionato

        focusedDelayAppID = nil

    }





    // Sincronizza i testi temporanei con i valori numerici salvati nelle applicazioni

    private func syncDelayTexts() {



        // Scorre tutte le applicazioni presenti nello store

        for app in store.apps {



            // Inserisce nel dizionario il valore numerico corrente

            delayTexts[app.id] = String(app.delay)

        }

    }





    // Controlla quali applicazioni configurate risultano realmente in esecuzione
    private func refreshRunningApplications() {

        // Recupera una sola volta l'elenco attuale delle applicazioni in esecuzione
        let runningApplications = NSWorkspace.shared.runningApplications.filter {
            !$0.isTerminated
        }

        // Crea un insieme contenente tutti i Bundle Identifier attualmente in esecuzione
        let runningBundleIdentifiers = Set(
            runningApplications.compactMap {
                $0.bundleIdentifier
            }
        )

        // Crea un insieme contenente tutti i percorsi delle applicazioni attualmente in esecuzione
        let runningApplicationPaths = Set(
            runningApplications.compactMap {
                $0.bundleURL?.standardizedFileURL.path
            }
        )

        // Prepara il nuovo insieme delle applicazioni configurate che risultano aperte
        var newRunningAppIDs: Set<UUID> = []


        // Controlla ogni applicazione configurata in Delayed Launcher
        for app in store.apps {

            // Normalizza il percorso dell'applicazione per rendere più affidabile il confronto
            let applicationURL = URL(
                fileURLWithPath: app.path
            ).standardizedFileURL

            // Recupera il Bundle Identifier direttamente dal pacchetto .app
            let bundleIdentifier = Bundle(
                url: applicationURL
            )?.bundleIdentifier


            // Controlla prima lo stato attraverso il Bundle Identifier
            let isRunningByBundleIdentifier: Bool

            if let bundleIdentifier {
                isRunningByBundleIdentifier = runningBundleIdentifiers.contains(
                    bundleIdentifier
                )
            } else {
                isRunningByBundleIdentifier = false
            }


            // Utilizza anche il percorso dell'applicazione come controllo aggiuntivo
            let isRunningByPath = runningApplicationPaths.contains(
                applicationURL.path
            )


            // Considera aperta l'applicazione se almeno uno dei due controlli ha successo
            if isRunningByBundleIdentifier || isRunningByPath {
                newRunningAppIDs.insert(app.id)
            }
        }


        // Evita di aggiornare inutilmente SwiftUI se lo stato non è realmente cambiato
        guard newRunningAppIDs != runningAppIDs else {
            return
        }

        // Aggiorna tutti i pallini dell'interfaccia contemporaneamente
        runningAppIDs = newRunningAppIDs
    }


    // Aggiorna lo stato poco dopo una notifica di apertura o chiusura ricevuta da macOS
    private func refreshRunningApplicationsAfterWorkspaceEvent() {

        // Crea un piccolo task per lasciare a macOS il tempo di aggiornare l'elenco dei processi
        Task { @MainActor in

            // Attende solamente 150 millisecondi
            try? await Task.sleep(
                nanoseconds: 150_000_000
            )

            // Esegue il controllo utilizzando lo stato aggiornato del sistema
            refreshRunningApplications()
        }
    }


    // Questa funzione apre il selettore standard di macOS per permettere all'utente di scegliere un'applicazione

    private func selectApplication() {



        // NSOpenPanel è la finestra standard di macOS utilizzata per scegliere file o applicazioni

        let panel = NSOpenPanel()



        // Impedisce di selezionare più applicazioni contemporaneamente

        panel.allowsMultipleSelection = false



        // Permette di selezionare file

        panel.canChooseFiles = true



        // Impedisce di selezionare normali cartelle

        panel.canChooseDirectories = false



        // Limita la selezione esclusivamente ai pacchetti applicazione di macOS

        panel.allowedContentTypes = [.applicationBundle]



        // Apre inizialmente la cartella Applicazioni del Mac

        panel.directoryURL = URL(fileURLWithPath: "/Applications")



        // Testo mostrato sul pulsante di conferma

        panel.prompt = "Aggiungi"



        // Titolo mostrato nella finestra di selezione

        panel.title = "Scegli un'applicazione"



        // Messaggio che spiega all'utente cosa deve selezionare

        panel.message = "Seleziona l'applicazione che vuoi gestire con Delayed Launcher"





        // Mostra la finestra e continua soltanto se l'utente preme il pulsante di conferma

        guard panel.runModal() == .OK else {

            return

        }



        // Recupera il percorso dell'applicazione scelta

        guard let selectedURL = panel.url else {

            return

        }



        // Rimuove l'estensione .app dal nome mostrato nell'interfaccia

        let applicationName = selectedURL.deletingPathExtension().lastPathComponent



        // Aggiunge l'applicazione selezionata allo store

        store.addApp(

            name: applicationName,

            path: selectedURL.path

        )



        // Mantiene automaticamente l'ordinamento scelto anche dopo l'aggiunta di una nuova applicazione

        store.sortAppsByName(

            ascending: sortMode == .nameAscending

        )



        // Aggiorna i campi numerici dopo l'aggiunta della nuova applicazione

        syncDelayTexts()



        // Aggiorna anche lo stato delle applicazioni aperte

        refreshRunningApplications()

    }

}





// Preview permette a Xcode di mostrare un'anteprima della schermata durante lo sviluppo

#Preview {

    ContentView()

}
