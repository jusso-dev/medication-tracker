import Foundation

struct StoredZipArchive {
    private var files: [(path: String, data: Data)] = []

    mutating func addFile(path: String, data: Data) {
        files.append((path, data))
    }

    func finalize() -> Data {
        var output = Data()
        var central = Data()
        var offset = 0

        for file in files {
            let name = Data(file.path.utf8)
            let crc = CRC32.hash(file.data)
            let size = UInt32(file.data.count)

            var local = Data()
            local.appendLittle32(0x04034b50)
            local.appendLittle16(20)
            local.appendLittle16(0)
            local.appendLittle16(0)
            local.appendLittle16(0)
            local.appendLittle16(0)
            local.appendLittle32(crc)
            local.appendLittle32(size)
            local.appendLittle32(size)
            local.appendLittle16(UInt16(name.count))
            local.appendLittle16(0)
            local.append(name)
            local.append(file.data)
            output.append(local)

            central.appendLittle32(0x02014b50)
            central.appendLittle16(20)
            central.appendLittle16(20)
            central.appendLittle16(0)
            central.appendLittle16(0)
            central.appendLittle16(0)
            central.appendLittle16(0)
            central.appendLittle32(crc)
            central.appendLittle32(size)
            central.appendLittle32(size)
            central.appendLittle16(UInt16(name.count))
            central.appendLittle16(0)
            central.appendLittle16(0)
            central.appendLittle16(0)
            central.appendLittle16(0)
            central.appendLittle32(0)
            central.appendLittle32(UInt32(offset))
            central.append(name)

            offset += local.count
        }

        let centralOffset = output.count
        output.append(central)
        output.appendLittle32(0x06054b50)
        output.appendLittle16(0)
        output.appendLittle16(0)
        output.appendLittle16(UInt16(files.count))
        output.appendLittle16(UInt16(files.count))
        output.appendLittle32(UInt32(central.count))
        output.appendLittle32(UInt32(centralOffset))
        output.appendLittle16(0)
        return output
    }

    static func unpack(_ data: Data) throws -> [String: Data] {
        var result: [String: Data] = [:]
        var cursor = 0
        while cursor + 30 <= data.count {
            let signature = data.readLittle32(at: cursor)
            if signature == 0x06054b50 || signature == 0x02014b50 {
                break
            }
            guard signature == 0x04034b50 else {
                throw BackupRestoreError.invalidArchive
            }
            let method = data.readLittle16(at: cursor + 8)
            let compressed = Int(data.readLittle32(at: cursor + 18))
            let uncompressed = Int(data.readLittle32(at: cursor + 22))
            let nameLength = Int(data.readLittle16(at: cursor + 26))
            let extraLength = Int(data.readLittle16(at: cursor + 28))
            let nameStart = cursor + 30
            let dataStart = nameStart + nameLength + extraLength
            guard method == 0,
                  dataStart + compressed <= data.count,
                  let name = String(
                    data: data.subdata(in: nameStart..<(nameStart + nameLength)),
                    encoding: .utf8
                  ) else {
                throw BackupRestoreError.invalidArchive
            }
            guard compressed == uncompressed else {
                throw BackupRestoreError.invalidArchive
            }
            result[name] = data.subdata(in: dataStart..<(dataStart + compressed))
            cursor = dataStart + compressed
        }
        guard result["manifest.json"] != nil else {
            throw BackupRestoreError.invalidArchive
        }
        return result
    }
}

enum CRC32 {
    static func hash(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let table: [UInt32] = {
        (0..<256).map { index in
            var crc = UInt32(index)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = 0xEDB8_8320 ^ (crc >> 1)
                } else {
                    crc >>= 1
                }
            }
            return crc
        }
    }()
}

private extension Data {
    mutating func appendLittle16(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendLittle32(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    func readLittle16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func readLittle32(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16
            | UInt32(self[offset + 3]) << 24
    }
}
