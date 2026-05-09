// MARK: - Auth Command Options

public struct AuthCommandOptions {
    public var `import`: Bool
    public var code: String?
    public var token: String?
    public var sid: String?
    public var delete: Bool
    public var disableWebview: Bool

    public init(
        import: Bool = false,
        code: String? = nil,
        token: String? = nil,
        sid: String? = nil,
        delete: Bool = false,
        disableWebview: Bool = false
    ) {
        self.import = `import`
        self.code = code
        self.token = token
        self.sid = sid
        self.delete = delete
        self.disableWebview = disableWebview
    }

    public init() {
        self.import = false
        self.code = nil
        self.token = nil
        self.sid = nil
        self.delete = false
        self.disableWebview = false
    }

    public func toArguments() -> [String] {
        var args: [String] = ["auth"]

        if `import` { args.append("--import") }

        if let code {
            args.append("--code")
            args.append(code)
        }

        if let token {
            args.append("--token")
            args.append(token)
        }

        if let sid {
            args.append("--sid")
            args.append(sid)
        }

        if delete { args.append("--delete") }
        if disableWebview { args.append("--disable-webview") }

        return args
    }
}
