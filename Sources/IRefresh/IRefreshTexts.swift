//
//  IRefreshTexts.swift
//  IRefresh
//
//  Created by ibabyblue on 2026/06/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import Foundation
import SwiftUI

/// Strings used by the built-in header/footer styles. Inject a custom instance
/// via `IRefreshScrollView.refreshTexts(_:)`.
public struct IRefreshTexts: Equatable, Sendable {
    public var pulling: String
    public var willRefresh: String
    public var refreshing: String
    public var loadMoreIdle: String
    public var willLoadMore: String
    public var loadingMore: String
    public var noMoreData: String
    /// Format string containing one `%@` placeholder for the time.
    public var lastUpdatedFormat: String
    public var lastUpdatedNever: String

    public init(
        pulling: String? = nil,
        willRefresh: String? = nil,
        refreshing: String? = nil,
        loadMoreIdle: String? = nil,
        willLoadMore: String? = nil,
        loadingMore: String? = nil,
        noMoreData: String? = nil,
        lastUpdatedFormat: String? = nil,
        lastUpdatedNever: String? = nil
    ) {
        self.pulling = pulling ?? String(localized: "irefresh.header.pulling", bundle: .module)
        self.willRefresh = willRefresh ?? String(localized: "irefresh.header.willRefresh", bundle: .module)
        self.refreshing = refreshing ?? String(localized: "irefresh.header.refreshing", bundle: .module)
        self.loadMoreIdle = loadMoreIdle ?? String(localized: "irefresh.footer.idle", bundle: .module)
        self.willLoadMore = willLoadMore ?? String(localized: "irefresh.footer.willLoad", bundle: .module)
        self.loadingMore = loadingMore ?? String(localized: "irefresh.footer.loading", bundle: .module)
        self.noMoreData = noMoreData ?? String(localized: "irefresh.footer.noMoreData", bundle: .module)
        self.lastUpdatedFormat = lastUpdatedFormat ?? String(localized: "irefresh.header.lastUpdated", bundle: .module)
        self.lastUpdatedNever = lastUpdatedNever ?? String(localized: "irefresh.header.lastUpdated.never", bundle: .module)
    }
}

extension EnvironmentValues {
    @Entry var iRefreshTexts = IRefreshTexts()
}
