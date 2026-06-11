import SwiftUI

/// Built-in header styles. Use the static factories: `.classic`,
/// `.classic(lastUpdatedKey:)`, `.minimal`.
public struct IRefreshHeaderStyle: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case classic(lastUpdatedKey: String?)
        case minimal
    }

    let kind: Kind

    /// Arrow + spinner + status text. No last-updated line.
    public static let classic = IRefreshHeaderStyle(kind: .classic(lastUpdatedKey: nil))

    /// Classic style with a "last updated" line persisted in `UserDefaults`
    /// under the given key (one key per list).
    public static func classic(lastUpdatedKey: String) -> IRefreshHeaderStyle {
        IRefreshHeaderStyle(kind: .classic(lastUpdatedKey: lastUpdatedKey))
    }

    /// Progress ring that becomes a spinner. No text.
    public static let minimal = IRefreshHeaderStyle(kind: .minimal)
}

/// Built-in footer styles: `.classic`, `.minimal`.
public struct IRefreshFooterStyle: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case classic
        case minimal
    }

    let kind: Kind

    public static let classic = IRefreshFooterStyle(kind: .classic)
    public static let minimal = IRefreshFooterStyle(kind: .minimal)
}

/// Header view produced by `.refreshHeader(_ style:)`.
public struct IRefreshStyledHeader: View {
    let style: IRefreshHeaderStyle
    let context: IRefreshContext

    public var body: some View {
        switch style.kind {
        case .classic(let lastUpdatedKey):
            IRefreshClassicHeader(context: context, lastUpdatedKey: lastUpdatedKey)
        case .minimal:
            IRefreshMinimalHeader(context: context)
        }
    }
}

/// Footer view produced by `.refreshFooter(_ style:)`.
public struct IRefreshStyledFooter: View {
    let style: IRefreshFooterStyle
    let context: IRefreshContext

    public var body: some View {
        switch style.kind {
        case .classic:
            IRefreshClassicFooter(context: context)
        case .minimal:
            IRefreshMinimalFooter(context: context)
        }
    }
}
