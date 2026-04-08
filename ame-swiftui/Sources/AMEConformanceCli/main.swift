import Foundation
import AMESwiftUI

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: ame-conformance <file.ame>\n", stderr)
    exit(1)
}

let path = CommandLine.arguments[1]
guard let data = FileManager.default.contents(atPath: path),
      let input = String(data: data, encoding: .utf8) else {
    fputs("Cannot read file: \(path)\n", stderr)
    exit(2)
}

let parser = AmeParser()
guard let tree = parser.parse(input) else {
    fputs("Parse returned nil\n", stderr)
    exit(3)
}

guard let json = AmeSerializer.toJson(tree) else {
    fputs("Serialization failed\n", stderr)
    exit(4)
}

print(json)
