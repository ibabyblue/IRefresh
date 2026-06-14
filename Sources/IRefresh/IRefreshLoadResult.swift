//
//  IRefreshLoadResult.swift
//  IRefresh
//
//  Created by ibabyblue on 2026/06/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

/// Returned by the `onLoadMore` action.
public enum IRefreshLoadResult: Equatable, Sendable {
    case hasMore
    /// Puts the footer into its terminal no-more-data state.
    case noMoreData
}
