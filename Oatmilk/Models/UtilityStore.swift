import Foundation
import Observation

@Observable
final class UtilityStore {
    private static let installedKey = "installedUtilities"

    var utilities: [UtilityInfo]

    var installedUtilities: [UtilityInfo] {
        utilities.filter { $0.isInstalled }
    }

    init() {
        var base = UtilityInfo.allUtilities
        let savedIDs = Self.loadInstalledIDs()
        for i in base.indices {
            if savedIDs.contains(base[i].id) {
                base[i].isInstalled = true
            }
        }
        self.utilities = base
    }

    func toggleInstall(_ utility: UtilityInfo) {
        guard let index = utilities.firstIndex(where: { $0.id == utility.id }) else { return }
        utilities[index].isInstalled.toggle()
        saveInstalledIDs()
    }

    func isInstalled(_ id: String) -> Bool {
        utilities.first(where: { $0.id == id })?.isInstalled ?? false
    }

    private func saveInstalledIDs() {
        let ids = utilities.filter { $0.isInstalled }.map { $0.id }
        UserDefaults.standard.set(ids, forKey: Self.installedKey)
    }

    private static func loadInstalledIDs() -> Set<String> {
        let ids = UserDefaults.standard.stringArray(forKey: installedKey) ?? []
        return Set(ids)
    }
}
