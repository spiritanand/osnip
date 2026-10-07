public enum Invocation: Sendable {
    case snip
    case printVersion
    case printUsage
    case rejectArguments

    public static let usage = """
    Usage: osnip
      Snip a screen region, shrink it to a WebP under 100 KB, and copy it to the clipboard.
      --version  Print the version.
    """

    public init(arguments: [String]) {
        switch arguments {
        case []: self = .snip
        case ["--version"]: self = .printVersion
        case ["--help"]: self = .printUsage
        default: self = .rejectArguments
        }
    }
}
