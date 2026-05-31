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
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    // 2. 뷰가 업데이트될 때 호출되며, URL이 바뀌었을 때만 로드합니다.
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // tel: / sms: 등 웹페이지의 특수 링크를 스마트폰의 전화·문자 앱으로 연결합니다.
    // WKWebView는 기본적으로 http(s) 외의 스킴을 처리하지 못해 직접 가로채야 합니다.
    final class Coordinator: NSObject, WKNavigationDelegate {
        /// 시스템 앱(전화/문자/메일 등)으로 넘겨줄 URL 스킴 목록.
        private static let externalSchemes: Set<String> = ["tel", "sms", "mailto", "facetime", "facetime-audio"]

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               Self.externalSchemes.contains(scheme) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
