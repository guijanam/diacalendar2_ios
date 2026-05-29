//
//  WebView.swift
//  DiaCalendar2
//
//  Created by Bum Son on 5/12/26.
//

import SwiftUI
import WebKit

// SwiftUI에서 웹페이지를 띄우기 위해 UIKit의 WKWebView를 연결해주는 구조체입니다.
struct WebView: UIViewRepresentable {
    let url: URL

    // 1. 초기 뷰를 생성하는 역할을 합니다.
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    // 2. 뷰가 업데이트될 때 호출되며, URL이 바뀌었을 때만 로드합니다.
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}
