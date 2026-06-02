//
//  TrainPositionSheet.swift
//  DiaCalendar2
//
//  특정 열번의 서울 지하철 실시간 위치를 보여주는 시트.
//  같은 방향 인접 열차(내 열차 ±1)를 함께 표시하고, 2호선 홀수 교대 보조용으로
//  "전 열번"이 주어지면 그 인접군도 합쳐서 보여준다.
//  데이터는 노선 전체의 현재 운행 열차만 제공하므로 캘린더 날짜와 무관하게 현재 시각 기준이다.
//

import SwiftUI
import Combine

struct TrainPositionSheet: View {
    let line: Int
    let myTrainNo: String
    /// 내 열번이 홀수일 때만 비어있지 않음(호출부가 결정). nil이면 내 열번만 조회.
    let previousTrainNo: String?

    @Environment(\.dismiss) private var dismiss

    private enum LoadState {
        case loading
        case loaded([SubwayPositionDTO])
        case empty
        case failed(String)
    }
    @State private var state: LoadState = .loading

    /// 자동 새로고침 주기(초).
    private let autoRefreshInterval = 20
    /// 다음 자동 새로고침까지 남은 초.
    @State private var countdown = 20
    /// 1초마다 카운트다운을 진행시키는 타이머.
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    ProgressView("실시간 위치 불러오는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    emptyView
                case .failed(let message):
                    failedView(message)
                case .loaded(let trains):
                    loadedList(trains)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("실시간 열차 위치")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Task { await load() } } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("\(countdown)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .task { await load() }
            .onReceive(timer) { _ in
                // 조회 중에는 카운트다운을 멈추고 대기.
                if case .loading = state { return }
                if countdown > 1 {
                    countdown -= 1
                } else {
                    Task { await load() }
                }
            }
        }
    }

    // MARK: - 상태별 뷰

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tram").font(.largeTitle).foregroundStyle(.secondary)
            Text("열번 \(myTrainNo) 열차를 현재 운행 목록에서 찾지 못했습니다.")
                .multilineTextAlignment(.center)
            Text("실시간 정보는 \(line)호선에서 지금 운행 중인 열차만 표시합니다. 캘린더에서 선택한 날짜와 무관하게 현재 시각 기준입니다.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(.secondary)
            Text("불러오기 실패").font(.headline)
            Text(message).font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("다시 시도") { Task { await load() } }.buttonStyle(.bordered)
        }
        .padding(24)
    }

    private func loadedList(_ trains: [SubwayPositionDTO]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(line)호선 · 현재 시각 기준")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(trains) { train in
                    trainCard(train)
                }
            }
            .padding(16)
        }
    }

    private func trainCard(_ t: SubwayPositionDTO) -> some View {
        let isMine = SubwayLine.sameTrain(t.trainNo, myTrainNo)
        let isPrev = previousTrainNo.map { SubwayLine.sameTrain(t.trainNo, $0) } ?? false
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(isMine ? Color.accentColor : (isPrev ? Color.orange : Color.secondary.opacity(0.4)))
                .frame(width: 4)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(t.statnNm).font(.headline)
                    if t.directAt == "1" {
                        badge("급행", color: .orange)
                    }
                    if isMine {
                        badge("내 열차", color: .accentColor)
                    } else if isPrev {
                        badge("전 열번", color: .orange)
                    }
                }
                Text("\(SubwayLine.directionLabel(updnLine: t.updnLine, line: line)) · \(SubwayLine.statusLabel(t.trainSttus)) · \(t.statnTnm ?? "")행")
                    .font(.caption).foregroundStyle(.secondary)
                Text("열번 \(t.trainNo)").font(.caption2).foregroundStyle(.secondary).monospaced()
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(isMine ? Color.accentColor.opacity(0.10)
                    : (isPrev ? Color.orange.opacity(0.08) : Color(.secondarySystemGroupedBackground)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }

    // MARK: - 로드 + 선택

    @MainActor
    private func load() async {
        state = .loading
        defer { countdown = autoRefreshInterval }  // 조회 종료 후 카운트다운 리셋
        do {
            let all = try await SeoulSubwayAPI.realtimePositions(line: line)
            let selected = selectTrains(in: all)
            state = selected.isEmpty ? .empty : .loaded(selected)
        } catch let SeoulSubwayAPIError.apiError(_, message) {
            // 데이터 없음(INFO-200 등)은 친절한 빈 상태로
            state = message.contains("데이터") ? .empty : .failed(message)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// 내 열번 인접군 + (있으면) 전 열번 인접군을 합쳐 dedup·정렬해 반환.
    private func selectTrains(in all: [SubwayPositionDTO]) -> [SubwayPositionDTO] {
        var result = Self.adjacentTrains(in: all, myTrainNo: myTrainNo)
        if let prev = previousTrainNo, !prev.isEmpty {
            result += Self.adjacentTrains(in: all, myTrainNo: prev)
        }
        // trainNo 기준 dedup 후 역 순번 정렬
        var seen = Set<String>()
        let deduped = result.filter { seen.insert($0.trainNo).inserted }
        return deduped.sorted { $0.stationSequence < $1.stationSequence }
    }

    /// 같은 방향(updnLine) 열차들을 statnId 순번으로 정렬 후 내 열차 앞/뒤 1대씩 추출.
    /// numTr 열번과 API trainNo는 앞 호선자리가 달라 뒤 3자리(suffix)로 매칭한다.
    static func adjacentTrains(in all: [SubwayPositionDTO], myTrainNo: String) -> [SubwayPositionDTO] {
        guard let mine = all.first(where: { SubwayLine.sameTrain($0.trainNo, myTrainNo) }) else { return [] }
        let sameDir = all
            .filter { $0.updnLine == mine.updnLine }
            .sorted { $0.stationSequence < $1.stationSequence }
        guard let idx = sameDir.firstIndex(where: { SubwayLine.sameTrain($0.trainNo, myTrainNo) }) else { return [mine] }
        let lower = max(0, idx - 1)
        let upper = min(sameDir.count - 1, idx + 1)
        return Array(sameDir[lower...upper])
    }
}
