import Foundation

/// A Convex argument value.
///
/// Convex's `v.number()` is float64. ConvexMobile encodes Swift `Int` as a 64-bit
/// `$integer`, which `v.number()` rejects, so every number here is a `Double`.
/// `v.optional(...)` rejects `null`, so optional arguments must be omitted rather than
/// sent as `.null` — see `ConvexArgs`.
public indirect enum ConvexValue: Equatable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([ConvexValue])
  case object([String: ConvexValue])

  /// Convex JSON wire format (keys sorted so output is stable).
  public func jsonString() -> String {
    switch self {
    case .null:
      return "null"
    case .bool(let value):
      return value ? "true" : "false"
    case .number(let value):
      return Self.encodeNumber(value)
    case .string(let value):
      return Self.encodeString(value)
    case .array(let values):
      return "[" + values.map { $0.jsonString() }.joined(separator: ",") + "]"
    case .object(let fields):
      let body = fields.keys.sorted().map { key in
        Self.encodeString(key) + ":" + fields[key]!.jsonString()
      }
      return "{" + body.joined(separator: ",") + "}"
    }
  }

  static func encodeNumber(_ value: Double) -> String {
    if !value.isFinite {
      // Convex JSON encodes non-finite floats as little-endian base64.
      var bits = value.bitPattern.littleEndian
      let data = withUnsafeBytes(of: &bits) { Data($0) }
      return "{\"$float\":\"\(data.base64EncodedString())\"}"
    }
    if value == value.rounded(), abs(value) < 9_007_199_254_740_992 {
      return String(Int64(value))
    }
    return "\(value)"
  }

  static func encodeString(_ value: String) -> String {
    var out = "\""
    for scalar in value.unicodeScalars {
      switch scalar {
      case "\"": out += "\\\""
      case "\\": out += "\\\\"
      case "\n": out += "\\n"
      case "\r": out += "\\r"
      case "\t": out += "\\t"
      default:
        if scalar.value < 0x20 {
          out += String(format: "\\u%04x", scalar.value)
        } else {
          out.unicodeScalars.append(scalar)
        }
      }
    }
    return out + "\""
  }
}

/// Anything that can be sent as a Convex argument.
public protocol ConvexRepresentable {
  var convexValue: ConvexValue { get }
}

extension String: ConvexRepresentable {
  public var convexValue: ConvexValue { .string(self) }
}

extension Double: ConvexRepresentable {
  public var convexValue: ConvexValue { .number(self) }
}

extension Int: ConvexRepresentable {
  public var convexValue: ConvexValue { .number(Double(self)) }
}

extension Bool: ConvexRepresentable {
  public var convexValue: ConvexValue { .bool(self) }
}

extension ConvexValue: ConvexRepresentable {
  public var convexValue: ConvexValue { self }
}

extension RawRepresentable where RawValue == String {
  public var convexValue: ConvexValue { .string(rawValue) }
}

/// Builds an argument object, dropping nil values so `v.optional` fields are omitted.
public func convexArgs(_ fields: KeyValuePairs<String, (any ConvexRepresentable)?>) -> [String: ConvexValue] {
  var out: [String: ConvexValue] = [:]
  for (key, value) in fields {
    if let value { out[key] = value.convexValue }
  }
  return out
}

/// A `null` result (mutations declared `returns: v.null()`).
public struct ConvexNull: Decodable, Equatable, Sendable {
  public init() {}
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    guard container.decodeNil() else {
      throw DecodingError.typeMismatch(
        ConvexNull.self,
        .init(codingPath: decoder.codingPath, debugDescription: "Expected null")
      )
    }
  }
}
