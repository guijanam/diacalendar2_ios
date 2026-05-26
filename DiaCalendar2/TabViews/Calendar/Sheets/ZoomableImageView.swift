//
//  ZoomableImageView.swift
//  DiaCalendar2
//

import SwiftUI

/// 핀치 줌 / 드래그 패닝 / 더블탭 확대·축소를 지원하는 이미지 뷰.
struct ZoomableImageView: View {
    let image: Image

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    private let doubleTapScale: CGFloat = 2.5

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            image
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnification(in: size))
                .simultaneousGesture(drag(in: size))
                .onTapGesture(count: 2) { handleDoubleTap(in: size) }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scale)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: offset)
        }
    }

    // MARK: - Gestures

    private func magnification(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = lastScale * value
                scale = min(max(proposed, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale {
                    resetZoom()
                } else {
                    offset = clampedOffset(offset, in: size)
                    lastOffset = offset
                }
            }
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > minScale else { return }
                offset = clampedOffset(offset, in: size)
                lastOffset = offset
            }
    }

    private func handleDoubleTap(in size: CGSize) {
        if scale > minScale {
            resetZoom()
        } else {
            scale = doubleTapScale
            lastScale = doubleTapScale
            offset = .zero
            lastOffset = .zero
        }
    }

    // MARK: - Helpers

    private func resetZoom() {
        scale = minScale
        lastScale = minScale
        offset = .zero
        lastOffset = .zero
    }

    /// 확대된 이미지가 화면 밖으로 너무 끌려나가지 않도록 이동 범위를 제한한다.
    private func clampedOffset(_ proposed: CGSize, in size: CGSize) -> CGSize {
        let maxX = max((size.width * scale - size.width) / 2, 0)
        let maxY = max((size.height * scale - size.height) / 2, 0)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
}
