import Foundation

struct AustralianMedicineEntry: Identifiable, Sendable {
    let genericName: String
    let commonBrands: [String]

    var id: String { genericName }

    var brandSummary: String {
        commonBrands.joined(separator: ", ")
    }

    var searchTerms: [String] {
        [genericName] + commonBrands
    }
}

enum AustralianMedicineCatalogue {
    static let entries: [AustralianMedicineEntry] = [
        entry("Allopurinol", "Zyloprim"),
        entry("Amlodipine", "Norvasc"),
        entry("Amoxicillin", "Amoxil"),
        entry("Amoxicillin with clavulanic acid", "Augmentin Duo Forte"),
        entry("Apixaban", "Eliquis"),
        entry("Aspirin", "Cartia"),
        entry("Atenolol", "Noten"),
        entry("Atorvastatin", "Lipitor"),
        entry("Azithromycin", "Zithromax"),
        entry("Bisoprolol", "Bicor"),
        entry("Budesonide with formoterol", "Symbicort"),
        entry("Candesartan", "Atacand"),
        entry("Cefalexin", "Keflex"),
        entry("Celecoxib", "Celebrex"),
        entry("Cetirizine", "Zyrtec"),
        entry("Clopidogrel", "Plavix", "Iscover"),
        entry("Colchicine", "Colgout"),
        entry("Dapagliflozin", "Forxiga"),
        entry("Diazepam", "Valium"),
        entry("Doxycycline", "Doryx"),
        entry("Empagliflozin", "Jardiance"),
        entry("Escitalopram", "Lexapro"),
        entry("Esomeprazole", "Nexium"),
        entry("Ethinylestradiol with levonorgestrel"),
        entry("Fexofenadine", "Telfast"),
        entry("Flucloxacillin", "Flopen"),
        entry("Fluoxetine", "Lovan", "Prozac"),
        entry("Fluticasone with salmeterol", "Seretide"),
        entry("Furosemide", "Lasix"),
        entry("Gabapentin", "Neurontin"),
        entry("Gliclazide", "Diamicron"),
        entry("Hydrochlorothiazide", "Dithiazide"),
        entry("Hydroxychloroquine", "Plaquenil"),
        entry("Ibuprofen", "Nurofen", "Brufen"),
        entry("Insulin glargine", "Lantus", "Optisulin"),
        entry("Irbesartan", "Avapro"),
        entry("Levothyroxine", "Oroxine", "Eutroxsig"),
        entry("Loratadine", "Claratyne"),
        entry("Meloxicam", "Mobic"),
        entry("Metformin", "Diabex"),
        entry("Methotrexate"),
        entry("Metoprolol", "Betaloc"),
        entry("Metronidazole", "Flagyl"),
        entry("Mirtazapine", "Avanza"),
        entry("Montelukast", "Singulair"),
        entry("Naproxen", "Naprosyn"),
        entry("Omeprazole", "Losec"),
        entry("Pantoprazole", "Somac"),
        entry("Paracetamol", "Panadol"),
        entry("Perindopril", "Coversyl"),
        entry("Prednisolone", "Panafcortelone"),
        entry("Pregabalin", "Lyrica"),
        entry("Quetiapine", "Seroquel"),
        entry("Ramipril", "Tritace"),
        entry("Rivaroxaban", "Xarelto"),
        entry("Rosuvastatin", "Crestor"),
        entry("Salbutamol", "Ventolin", "Asmol"),
        entry("Semaglutide", "Ozempic", "Rybelsus"),
        entry("Sertraline", "Zoloft"),
        entry("Simvastatin", "Zocor"),
        entry("Spironolactone", "Aldactone"),
        entry("Telmisartan", "Micardis"),
        entry("Tiotropium", "Spiriva"),
        entry("Trimethoprim", "Alprim"),
        entry("Venlafaxine", "Efexor XR"),
        entry("Warfarin", "Coumadin", "Marevan")
    ].sorted {
        $0.genericName.localizedStandardCompare($1.genericName) == .orderedAscending
    }

    static func search(_ query: String, limit: Int = 8) -> [AustralianMedicineEntry] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return Array(entries.prefix(limit)) }

        return entries
            .filter { entry in
                entry.searchTerms.contains {
                    $0.localizedStandardContains(term)
                }
            }
            .prefix(limit)
            .map { $0 }
    }

    static func match(in text: String) -> AustralianMedicineEntry? {
        entries
            .compactMap { entry -> (entry: AustralianMedicineEntry, length: Int)? in
                let longestMatch = entry.searchTerms
                    .filter { text.localizedStandardContains($0) }
                    .map(\.count)
                    .max()
                return longestMatch.map { (entry, $0) }
            }
            .max { $0.length < $1.length }?
            .entry
    }

    private static func entry(
        _ genericName: String,
        _ commonBrands: String...
    ) -> AustralianMedicineEntry {
        AustralianMedicineEntry(
            genericName: genericName,
            commonBrands: commonBrands
        )
    }
}
