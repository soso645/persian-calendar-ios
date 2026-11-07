import Foundation

/// A city from the bundled `cities.json`, used by the location picker.
struct CityItem: Identifiable, Hashable, Sendable {
    let key: String
    let en: String
    let fa: String
    let ckb: String
    let ar: String
    let countryCode: String
    let countryEn: String
    let countryFa: String
    let countryCkb: String
    let countryAr: String
    let coordinates: Coordinates

    var id: String { key }

    func localizedName(for language: AppLanguage) -> String {
        switch language {
        case .fa: fa.isEmpty ? en : fa
        case .ar: ar.isEmpty ? en : ar
        case .en: en
        }
    }

    func localizedCountry(for language: AppLanguage) -> String {
        switch language {
        case .fa: countryFa.isEmpty ? countryEn : countryFa
        case .ar: countryAr.isEmpty ? countryEn : countryAr
        case .en: countryEn
        }
    }
}

/// The bundled city list, loaded once.
enum CitiesData {
    static let shared: [CityItem] = {
        guard let url = Bundle.main.url(forResource: "cities", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            preconditionFailure("cities.json is missing from the app bundle")
        }
        do {
            return try parse(data)
        } catch {
            preconditionFailure("cities.json could not be parsed: \(error)")
        }
    }()

    static func parse(_ data: Data) throws -> [CityItem] {
        let root = try JSONDecoder().decode([String: RawCountry].self, from: data)
        return root.flatMap { countryCode, country in
            country.cities.map { key, city in
                CityItem(
                    key: key,
                    en: city.en, fa: city.fa, ckb: city.ckb, ar: city.ar,
                    countryCode: countryCode,
                    countryEn: country.en, countryFa: country.fa,
                    countryCkb: country.ckb, countryAr: country.ar,
                    coordinates: Coordinates(
                        latitude: city.latitude,
                        longitude: city.longitude,
                        elevation: city.elevation))
            }
        }.sorted { $0.key < $1.key }
    }

    private struct RawCountry: Decodable {
        let en: String
        let fa: String
        let ckb: String
        let ar: String
        let cities: [String: RawCity]
    }

    private struct RawCity: Decodable {
        let en: String
        let fa: String
        let ckb: String
        let ar: String
        let latitude: Double
        let longitude: Double
        let elevation: Double
    }
}
