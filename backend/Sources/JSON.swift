import Glibc

// MARK: - JSON Value

indirect enum JSONValue {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case null
    case array([JSONValue])
    case object([(key: String, value: JSONValue)])
}

extension JSONValue {
    var asString: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    var asInt: Int? {
        if case .integer(let i) = self { return i }
        if case .double(let d) = self { return Int(d) }
        return nil
    }
    var asDouble: Double? {
        if case .double(let d) = self { return d }
        if case .integer(let i) = self { return Double(i) }
        return nil
    }
    var asBool: Bool? {
        if case .boolean(let b) = self { return b }
        return nil
    }
    var asArray: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
    var asObject: [(key: String, value: JSONValue)]? {
        if case .object(let o) = self { return o }
        return nil
    }
    subscript(key: String) -> JSONValue? {
        guard case .object(let pairs) = self else { return nil }
        return pairs.first(where: { $0.key == key })?.value
    }
}

// MARK: - JSON Encoder

extension JSONValue {
    var json: String {
        switch self {
        case .string(let s):   return "\"" + s.jsonEscaped + "\""
        case .integer(let i):  return String(i)
        case .double(let d):
            if d.truncatingRemainder(dividingBy: 1) == 0 && abs(d) < 1e15 {
                return String(Int(d)) + ".0"
            }
            return String(d)
        case .boolean(let b):  return b ? "true" : "false"
        case .null:            return "null"
        case .array(let arr):
            return "[" + arr.map { $0.json }.joined(separator: ",") + "]"
        case .object(let pairs):
            let kvs = pairs.map { "\"" + $0.key.jsonEscaped + "\":" + $0.value.json }
            return "{" + kvs.joined(separator: ",") + "}"
        }
    }
}

extension String {
    var jsonEscaped: String {
        var result = ""
        for char in self {
            switch char {
            case "\\": result += "\\\\"
            case "\"": result += "\\\""
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:   result.append(char)
            }
        }
        return result
    }
}

// MARK: - JSON Parser

struct JSONParser {
    private let chars: [Character]
    private var pos: Int = 0

    init(_ string: String) {
        self.chars = Array(string)
    }

    mutating func parse() -> JSONValue? {
        skipWhitespace()
        return parseValue()
    }

    private mutating func parseValue() -> JSONValue? {
        guard pos < chars.count else { return nil }
        switch chars[pos] {
        case "\"":            return parseString().map { .string($0) }
        case "{":             return parseObject()
        case "[":             return parseArray()
        case "t":             return consume("true")  ? .boolean(true)  : nil
        case "f":             return consume("false") ? .boolean(false) : nil
        case "n":             return consume("null")  ? .null           : nil
        case "-", "0"..."9":  return parseNumber()
        default:              return nil
        }
    }

    private mutating func parseString() -> String? {
        guard pos < chars.count, chars[pos] == "\"" else { return nil }
        pos += 1
        var result = ""
        while pos < chars.count && chars[pos] != "\"" {
            let ch = chars[pos]
            pos += 1
            if ch == "\\" {
                guard pos < chars.count else { return nil }
                let esc = chars[pos]; pos += 1
                switch esc {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/":  result.append("/")
                case "n":  result.append("\n")
                case "r":  result.append("\r")
                case "t":  result.append("\t")
                case "u":
                    var hex = ""
                    for _ in 0..<4 {
                        guard pos < chars.count else { return nil }
                        hex.append(chars[pos]); pos += 1
                    }
                    if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                        result.append(Character(scalar))
                    }
                default: result.append(esc)
                }
            } else {
                result.append(ch)
            }
        }
        guard pos < chars.count else { return nil }
        pos += 1
        return result
    }

    private mutating func parseObject() -> JSONValue? {
        guard pos < chars.count, chars[pos] == "{" else { return nil }
        pos += 1
        var pairs: [(key: String, value: JSONValue)] = []
        skipWhitespace()
        if pos < chars.count && chars[pos] == "}" { pos += 1; return .object(pairs) }
        while pos < chars.count {
            skipWhitespace()
            guard let key = parseString() else { return nil }
            skipWhitespace()
            guard pos < chars.count, chars[pos] == ":" else { return nil }
            pos += 1
            skipWhitespace()
            guard let value = parseValue() else { return nil }
            pairs.append((key: key, value: value))
            skipWhitespace()
            guard pos < chars.count else { return nil }
            if chars[pos] == "}" { pos += 1; return .object(pairs) }
            guard chars[pos] == "," else { return nil }
            pos += 1
        }
        return nil
    }

    private mutating func parseArray() -> JSONValue? {
        guard pos < chars.count, chars[pos] == "[" else { return nil }
        pos += 1
        var items: [JSONValue] = []
        skipWhitespace()
        if pos < chars.count && chars[pos] == "]" { pos += 1; return .array(items) }
        while pos < chars.count {
            skipWhitespace()
            guard let value = parseValue() else { return nil }
            items.append(value)
            skipWhitespace()
            guard pos < chars.count else { return nil }
            if chars[pos] == "]" { pos += 1; return .array(items) }
            guard chars[pos] == "," else { return nil }
            pos += 1
        }
        return nil
    }

    private mutating func parseNumber() -> JSONValue? {
        var raw = ""
        var isDouble = false
        if pos < chars.count && chars[pos] == "-" { raw.append(chars[pos]); pos += 1 }
        while pos < chars.count && chars[pos] >= "0" && chars[pos] <= "9" {
            raw.append(chars[pos]); pos += 1
        }
        if pos < chars.count && chars[pos] == "." {
            isDouble = true; raw.append(chars[pos]); pos += 1
            while pos < chars.count && chars[pos] >= "0" && chars[pos] <= "9" {
                raw.append(chars[pos]); pos += 1
            }
        }
        if pos < chars.count && (chars[pos] == "e" || chars[pos] == "E") {
            isDouble = true; raw.append(chars[pos]); pos += 1
            if pos < chars.count && (chars[pos] == "+" || chars[pos] == "-") {
                raw.append(chars[pos]); pos += 1
            }
            while pos < chars.count && chars[pos] >= "0" && chars[pos] <= "9" {
                raw.append(chars[pos]); pos += 1
            }
        }
        if isDouble, let d = Double(raw) { return .double(d) }
        if let i = Int(raw) { return .integer(i) }
        return Double(raw).map { .double($0) }
    }

    private mutating func consume(_ literal: String) -> Bool {
        let chars2 = Array(literal)
        guard pos + chars2.count <= chars.count else { return false }
        for (i, c) in chars2.enumerated() {
            if chars[pos + i] != c { return false }
        }
        pos += chars2.count
        return true
    }

    private mutating func skipWhitespace() {
        while pos < chars.count && (chars[pos] == " " || chars[pos] == "\n" || chars[pos] == "\r" || chars[pos] == "\t") {
            pos += 1
        }
    }
}

func parseJSON(_ s: String) -> JSONValue? {
    var p = JSONParser(s)
    return p.parse()
}
