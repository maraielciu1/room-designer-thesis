//
//  ScannedFurnitureEntity.swift
//  RoomScanTest
//
//  SwiftData record for ScannedFurniture. USDZ and PLY files stay on disk;
//  only filenames and metadata are stored here.
//

import Foundation
import SwiftData

@Model
final class ScannedFurnitureEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var userId: UUID
    var usdzFileName: String
    var category: String
    var createdAt: Date
    var fileSizeBytes: Int64?
    var realWorldDimensionsJSON: String?
    var splatFileName: String?
    var splatGaussianCount: Int?
    var splatFileSizeBytes: Int64?
    var reconstructionMethod: String?

    init(from item: ScannedFurniture) {
        self.id = item.id
        self.name = item.name
        self.userId = item.userId
        self.usdzFileName = item.usdzFileName
        self.category = item.category
        self.createdAt = item.createdAt
        self.fileSizeBytes = item.fileSizeBytes
        self.realWorldDimensionsJSON = item.realWorldDimensions.map { Self.encodeDoubles($0) }
        self.splatFileName = item.splatFileName
        self.splatGaussianCount = item.splatGaussianCount
        self.splatFileSizeBytes = item.splatFileSizeBytes
        self.reconstructionMethod = item.reconstructionMethod
    }

    func update(from item: ScannedFurniture) {
        name = item.name
        category = item.category
        fileSizeBytes = item.fileSizeBytes
        realWorldDimensionsJSON = item.realWorldDimensions.map { Self.encodeDoubles($0) }
        splatFileName = item.splatFileName
        splatGaussianCount = item.splatGaussianCount
        splatFileSizeBytes = item.splatFileSizeBytes
        reconstructionMethod = item.reconstructionMethod
    }

    func toScannedFurniture() -> ScannedFurniture {
        ScannedFurniture(
            id: id,
            name: name,
            userId: userId,
            usdzFileName: usdzFileName,
            category: category,
            createdAt: createdAt,
            fileSizeBytes: fileSizeBytes,
            realWorldDimensions: realWorldDimensionsJSON.map { Self.decodeDoubles($0) },
            splatFileName: splatFileName,
            splatGaussianCount: splatGaussianCount,
            splatFileSizeBytes: splatFileSizeBytes,
            reconstructionMethod: reconstructionMethod
        )
    }

    private static func encodeDoubles(_ values: [Double]) -> String {
        (try? String(data: JSONEncoder().encode(values), encoding: .utf8)) ?? "[]"
    }

    private static func decodeDoubles(_ json: String) -> [Double] {
        guard let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([Double].self, from: data) else { return [] }
        return values
    }
}
