//
//  DayDetailSheet.swift
//  DiaCalendar2
//

import SwiftUI
import Yotei

struct DayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let date: Date
    let calendar: Calendar
    let events: [YoteiEvent<EventData>]
    let loadCalendars: () async -> [EKCalendarInfo]
    let loadMemos: (Date) async -> [DateMemoDTO]
    let loadShiftInfo: ((Date) async -> ShiftDayInfo?)?
    let holidayName: ((Date) -> String?)?
    let onSelectEvent: (String) -> Void
    let onCreate: () -> Void
    let onDeleteOverlay: (() async -> Void)?
    let onToggleMemo: (DateMemoDTO) -> Void
    let onDeleteMemo: (DateMemoDTO) -> Void

    // 자식 시트(메모/근무 편집)에서 사용하는 의존성. 부모 시트를 닫지 않고
    // DayDetailSheet 내부에서 직접 띄우기 위해 viewModel 동작을 클로저로 주입받는다.
    let saveMemo: (DateMemoDTO) async -> Void
    let deleteMemo: (UUID) async -> Void
    let loadShiftOptions: () async -> [String]
    let loadShiftInputTypes: () async -> [ShiftInputTypeDTO]
    /// 해당 날짜에 지근이 설정되어 있는지 확인. 지근충당 등록 제한에 사용.
    let isJiGeunDay: (Date) async -> Bool
    let loadAttendanceTypes: () async -> [AttendanceTypeDTO]
    let createSwap: (_ targetShiftName: String, _ days: Int) async -> Void
    let createShiftInput: (_ type: ShiftInputTypeDTO, _ days: Int, _ targetShiftName: String) async -> Void
    let createAttendance: (_ type: AttendanceTypeDTO, _ days: Int) async -> Void
    /// 지근/지휴 등록. 근태와 동일한 흐름이지만 분류(category)를 함께 저장한다.
    let createJiGeunHyu: (_ category: AttendanceCategory, _ days: Int) async -> Void
    let loadLunarAnniversaries: () async -> [LunarAnniversaryDTO]
    let saveLunarAnniversary: (LunarAnniversaryDTO) async -> Void
    let deleteLunarAnniversary: (UUID) async -> Void

    private enum DayChildSheet: Identifiable {
        case memoEditor(MemoEditorMode)
        case shiftSwap
        case shiftInput
        case attendance
        case lunarAnniversaryEditor(LunarAnniversaryEditorMode)

        var id: String {
            switch self {
            case .memoEditor(.new(let d)): return "memo-new-\(d.timeIntervalSince1970)"
            case .memoEditor(.edit(let dto)): return "memo-edit-\(dto.id.uuidString)"
            case .shiftSwap: return "shiftSwap"
            case .shiftInput: return "shiftInput"
            case .attendance: return "attendance"
            case .lunarAnniversaryEditor(.new(let m, let d)): return "lunar-new-\(m)-\(d)"
            case .lunarAnniversaryEditor(.edit(let dto)): return "lunar-edit-\(dto.id.uuidString)"
            }
        }
    }

    @State private var childSheet: DayChildSheet?

    @State private var memos: [DateMemoDTO] = []
    @State private var lunarAnniversaries: [LunarAnniversaryDTO] = []
    @State private var swipedMemoID: UUID?
    @State private var draggingMemoID: UUID?
    @State private var dragOffsetX: CGFloat = 0
    @State private var pendingDeleteMemo: DateMemoDTO?
    @State private var calendarsById: [String: EKCalendarInfo] = [:]
    @State private var shiftInfo: ShiftDayInfo?
    @State private var isShiftBadgePressed = false
    @State private var isRestorePressed = false
    @State private var showShiftImage = false
    @State private var showInvalidImageAlert = false
    @State private var shiftImageURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let info = shiftInfo {
                            shiftSection(info: info)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("메모")
                            if memos.isEmpty {
                                emptyPlaceholder("메모 없음")
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(memos, id: \.id) { memo in
                                        memoCard(for: memo)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("음력 기념일")
                            if lunarAnniversaries.isEmpty {
                                emptyPlaceholder("음력 기념일 없음")
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(lunarAnniversaries, id: \.id) { anniversary in
                                        lunarAnniversaryCard(for: anniversary)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("이벤트")
                            // 근무 정보는 위 "근무" GroupBox 에서 이미 표시하므로 이벤트 섹션에서는 제외.
                            // 음력 기념일도 전용 섹션에서 표시하므로 제외.
                            let nonMemoEvents = events.filter {
                                $0.data.kind != .memo && $0.data.kind != .shift && $0.data.kind != .lunarAnniversary
                            }
                            if nonMemoEvents.isEmpty {
                                emptyPlaceholder("이벤트 없음")
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(nonMemoEvents, id: \.id) { event in
                                        eventCard(for: event)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))

                actionBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    headerTitle
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onCreate()
                    } label: {
                        Label("추가", systemImage: "plus")
                    }
                }
            }
            .task {
                memos = await loadMemos(date)
                let infos = await loadCalendars()
                calendarsById = Dictionary(uniqueKeysWithValues: infos.map { ($0.identifier, $0) })
                await reloadShiftInfo()
                await reloadLunarAnniversaries()
            }
            .sheet(isPresented: $showShiftImage) {
                shiftImageSheet
            }
            .sheet(item: $childSheet, onDismiss: {
                Task {
                    memos = await loadMemos(date)
                    await reloadShiftInfo()
                    await reloadLunarAnniversaries()
                }
            }) { sheet in
                childSheetContent(for: sheet)
            }
            .alert("이미지 없음", isPresented: $showInvalidImageAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("이 근무에는 등록된 근무표 이미지가 없습니다.")
            }
            .alert("메모를 삭제하시겠습니까?", isPresented: Binding(
                get: { pendingDeleteMemo != nil },
                set: { if !$0 { pendingDeleteMemo = nil } }
            )) {
                Button("삭제", role: .destructive) {
                    if let memo = pendingDeleteMemo {
                        withAnimation {
                            memos.removeAll { $0.id == memo.id }
                        }
                        onDeleteMemo(memo)
                    }
                    pendingDeleteMemo = nil
                    swipedMemoID = nil
                }
                Button("취소", role: .cancel) { pendingDeleteMemo = nil }
            }
        }
    }

    @ViewBuilder
    private var shiftImageSheet: some View {
        NavigationStack {
            Group {
                if let url = shiftImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            ZoomableImageView(image: image)
                        case .failure:
                            VStack(spacing: 8) {
                                Image(systemName: "photo").font(.largeTitle)
                                Text("이미지를 불러올 수 없습니다.\nthridtime에 이미지 주소를 입력해야 합니다.\n일반텍스트는 텍스트로 표시됩니다.").font(.footnote)
                            }
                            .foregroundStyle(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("근무표")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { showShiftImage = false }
                }
            }
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                actionButton(title: "메모", systemImage: "square.and.pencil") {
                    childSheet = .memoEditor(.new(date: date))
                }
                actionButton(title: "음력기념일", systemImage: "moon.stars") {
                    let (month, day) = LunarSolarConverter.lunarMonthDay(from: date, calendar: calendar)
                    childSheet = .lunarAnniversaryEditor(.new(lunarMonth: month, lunarDay: day))
                }
                if shiftInfo?.config?.isCustomShift == false {
                    actionButton(title: "교번교체", systemImage: "arrow.left.arrow.right") {
                        childSheet = .shiftSwap
                    }
                    actionButton(title: "충당", systemImage: "plus.rectangle.on.rectangle") {
                        childSheet = .shiftInput
                    }
                }
                actionButton(title: "근태(휴가)", systemImage: "tag") {
                    childSheet = .attendance
                }
                actionButton(
                    title: "지근",
                    systemImage: "calendar.badge.minus",
                    tint: Color(hex: AttendanceCategory.jigeun.colorHex)
                ) {
                    handleJiGeunHyu(.jigeun)
                }
                actionButton(
                    title: "지휴",
                    systemImage: "calendar.badge.plus",
                    tint: Color(hex: AttendanceCategory.jihyu.colorHex)
                ) {
                    handleJiGeunHyu(.jihyu)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    @ViewBuilder
    private func shiftSection(info: ShiftDayInfo) -> some View {
        let isCustom = info.config?.isCustomShift == true
        let hasOverlay = info.swap != nil || info.input != nil || info.attendance != nil
        let dia = info.dia
        let firstTime = dia?.firstTime ?? ""
        let secondTime = dia?.secondTime ?? ""
        let numTr1 = dia?.numTr1 ?? ""
        let numTr2 = dia?.numTr2 ?? ""
        let showFirstHalf = !isCustom && !firstTime.isEmpty
        let showSecondHalf = !isCustom && !secondTime.isEmpty

        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    shiftBadge(info: info)

                    if isCustom {
                        Text(info.config?.officeName ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(dia?.workTime ?? "")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .monospaced()
                                
                                switch thirdTimeKind(info) {
                                case .none:
                                    EmptyView()
                                case .url(let url):
                                    Button {
                                        shiftImageURL = url
                                        showShiftImage = true
                                    } label: {
                                        Label("시간표", systemImage: "photo")
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.accentColor.opacity(0.12))
                                            .foregroundColor(.accentColor)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                case .text(let plain):
                                    Text(plain)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            switch valueKind(dia?.totalTime) {
                            case .none:
                                EmptyView()
                            case .url(let url):
                                Button {
                                    shiftImageURL = url
                                    showShiftImage = true
                                } label: {
                                    Label("참고", systemImage: "photo")
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.accentColor.opacity(0.12))
                                        .foregroundColor(.accentColor)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            case .text(let plain):
                                Text("참고 -\(plain)-")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if hasOverlay {
                        restoreButton(baseShiftName: info.baseShiftName)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showFirstHalf {
                    Divider()
                    halfSection(label: "<전반>", trainNumber: numTr1, time: firstTime)
                }

                if showSecondHalf {
                    Divider()
                    halfSection(label: "<후반>", trainNumber: numTr2, time: secondTime)
                }
            }
        }
        .groupBoxStyle(MusicPlayerGroupBoxStyle())
    }

    @ViewBuilder
    private func shiftBadge(info: ShiftDayInfo) -> some View {
        let effective = info.effectiveShiftName
        let colorHex = info.effectiveColorHex
        let color = colorHex.flatMap { Color(hex: $0) } ?? .primary
        // 라이트 모드에서 밝은 색(지근 하늘색 등)은 흰 배경과 대비가 약하므로 글자색만 진하게 보정.
        let textColor = ContrastPalette.readableForeground(color, scheme: colorScheme)

        Button {
            handleShiftBadgeTap(info: info)
        } label: {
            Text(effective)
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundColor(textColor)
                .frame(width: 70, height: 55)
                .background(color.opacity(0.1))
                .clipShape(Circle())
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 5,
                    x: 0,
                    y: isShiftBadgePressed ? 1 : 3
                )
                .scaleEffect(isShiftBadgePressed ? 0.95 : 1.0)
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0),
                    value: isShiftBadgePressed
                )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isShiftBadgePressed = true }
                .onEnded { _ in isShiftBadgePressed = false }
        )
    }

    /// 값의 종류: 없음 / URL(이미지 링크) / 단순 문자
    private enum ValueKind {
        case none
        case url(URL)
        case text(String)
    }

    /// 임의 문자열을 URL / 단순 문자 / 없음으로 분류한다.
    private func valueKind(_ raw: String?) -> ValueKind {
        let raw = raw ?? ""
        guard !raw.isEmpty else { return .none }
        if (raw.hasPrefix("http://") || raw.hasPrefix("https://")), let url = URL(string: raw) {
            return .url(url)
        }
        return .text(raw)
    }

    private func thirdTimeKind(_ info: ShiftDayInfo) -> ValueKind {
        valueKind(info.dia?.thirdTime)
    }

    private func reloadShiftInfo() async {
        if let loader = loadShiftInfo {
            shiftInfo = await loader(date)
        }
    }

    private func reloadLunarAnniversaries() async {
        let all = await loadLunarAnniversaries()
        // 해당 날짜에 해당하는 기념일만 필터링
        let cal = calendar
        lunarAnniversaries = all.filter { dto in
            LunarSolarConverter.solarDate(
                lunarYear: cal.component(.year, from: date),
                lunarMonth: dto.lunarMonth,
                lunarDay: dto.lunarDay,
                isLeapMonth: dto.isLeapMonth,
                calendar: cal
            ).map { cal.isDate($0, inSameDayAs: date) } ?? false
        }
    }

    @ViewBuilder
    private func lunarAnniversaryCard(for dto: LunarAnniversaryDTO) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: dto.colorHex) ?? .gray)
                .frame(width: 6)
                .frame(height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(dto.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("음력 \(dto.lunarMonth)월 \(dto.lunarDay)일\(dto.isLeapMonth ? " (윤달)" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                childSheet = .lunarAnniversaryEditor(.edit(dto))
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func childSheetContent(for sheet: DayChildSheet) -> some View {
        switch sheet {
        case .memoEditor(let mode):
            MemoEditorSheet(
                mode: mode,
                calendar: calendar,
                onSave: { dto in Task { await saveMemo(dto) } },
                onDelete: { id in Task { await deleteMemo(id) } }
            )
        case .shiftSwap:
            ShiftSwapSheet(
                date: date,
                loadOptions: { await loadShiftOptions() },
                onConfirm: { targetName, days in
                    Task { await createSwap(targetName, days) }
                }
            )
        case .shiftInput:
            ShiftInputSheet(
                date: date,
                loadTypes: { await loadShiftInputTypes() },
                loadOptions: { await loadShiftOptions() },
                isJiGeunDay: { await isJiGeunDay($0) },
                onConfirm: { type, days, target in
                    Task { await createShiftInput(type, days, target) }
                }
            )
        case .attendance:
            AttendanceSheet(
                date: date,
                loadTypes: { await loadAttendanceTypes() },
                onConfirm: { type, days in
                    Task { await createAttendance(type, days) }
                }
            )
        case .lunarAnniversaryEditor(let mode):
            LunarAnniversaryEditorSheet(
                mode: mode,
                onSave: { dto in Task { await saveLunarAnniversary(dto) } },
                onDelete: { id in Task { await deleteLunarAnniversary(id) } }
            )
        }
    }

    /// 본근무 복원: 시트를 닫지 않고 근무 정보만 갱신한다.
    private func handleRestoreOverlay() {
        guard let onDeleteOverlay else { return }
        Task {
            await onDeleteOverlay()
            await reloadShiftInfo()
        }
    }

    private func handleShiftBadgeTap(info: ShiftDayInfo) {
        let raw = info.dia?.thirdTime ?? ""
        if (raw.hasPrefix("http://") || raw.hasPrefix("https://")), let url = URL(string: raw) {
            shiftImageURL = url
            showShiftImage = true
        } else {
            showInvalidImageAlert = true
        }
    }

    /// 지근/지휴 등록: 시트를 닫지 않고 근무 정보만 갱신한다.
    private func handleJiGeunHyu(_ category: AttendanceCategory) {
        Task {
            await createJiGeunHyu(category, 1)
            await reloadShiftInfo()
        }
    }

    @ViewBuilder
    private func restoreButton(baseShiftName: String) -> some View {
        Button {
            handleRestoreOverlay()
        } label: {
            VStack(spacing: 2) {
                Text("원래 근무").font(.caption2)
                Text(baseShiftName).fontWeight(.bold)
            }
            .padding(8)
            .foregroundColor(.secondary)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .shadow(
                color: Color.black.opacity(0.2),
                radius: 5,
                x: 0,
                y: isRestorePressed ? 1 : 3
            )
            .scaleEffect(isRestorePressed ? 0.95 : 1.0)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0),
                value: isRestorePressed
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isRestorePressed = true }
                .onEnded { _ in isRestorePressed = false }
        )
    }

    @ViewBuilder
    private func halfSection(label: String, trainNumber: String, time: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.footnote)
                if !trainNumber.isEmpty {
                    Text(trainNumber)
                        .font(.subheadline)
                        .monospaced()
                        .tracking(-0.2)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(time)
                    .font(.headline)
                    .monospaced()
                    .tracking(-0.5)
                    .fontWeight(.semibold)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(
                        maxWidth: trainNumber.isEmpty ? .infinity : .none,
                        alignment: .leading
                    )
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func actionButton(
        title: String,
        systemImage: String,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .regular))
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .foregroundStyle(tint ?? Color.accentColor)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }

    @ViewBuilder
    private func emptyPlaceholder(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private static let memoDeleteWidth: CGFloat = 80

    @ViewBuilder
    private func memoCard(for memo: DateMemoDTO) -> some View {
        let isSwiped = swipedMemoID == memo.id
        let offsetX: CGFloat = {
            if draggingMemoID == memo.id { return dragOffsetX }
            return isSwiped ? -Self.memoDeleteWidth : 0
        }()

        ZStack(alignment: .trailing) {
            Button {
                pendingDeleteMemo = memo
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .semibold))
                    Text("삭제")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .frame(width: Self.memoDeleteWidth)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            memoCardBody(for: memo, baseColor: Color(hex: memo.colorHex) ?? .accentColor)
                .offset(x: offsetX)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            draggingMemoID = memo.id
                            let base: CGFloat = isSwiped ? -Self.memoDeleteWidth : 0
                            let proposed = base + value.translation.width
                            dragOffsetX = min(0, max(-Self.memoDeleteWidth, proposed))
                        }
                        .onEnded { _ in
                            let shouldOpen = dragOffsetX <= -Self.memoDeleteWidth / 2
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                swipedMemoID = shouldOpen ? memo.id : nil
                            }
                            draggingMemoID = nil
                            dragOffsetX = 0
                        }
                )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSwiped)
    }

    @ViewBuilder
    private func memoCardBody(for memo: DateMemoDTO, baseColor: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                var updated = memo
                updated.isDone.toggle()
                updated.updatedAt = Date()
                onToggleMemo(updated)
                if let idx = memos.firstIndex(where: { $0.id == memo.id }) {
                    memos[idx] = updated
                }
            } label: {
                Image(systemName: memo.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(memo.isDone ? Color.green : Color.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            RoundedRectangle(cornerRadius: 3)
                .fill(baseColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(memo.title.isEmpty ? "메모" : memo.title)
                    .strikethrough(memo.isDone, color: .primary)
                    .font(.headline)
                    .foregroundStyle(Color.primary.opacity(memo.isDone ? 0.5 : 1.0))
                    .lineLimit(2)

                if !memo.body.isEmpty {
                    Text(memo.body)
                        .font(.caption)
                        .foregroundStyle(Color.secondary.opacity(memo.isDone ? 0.6 : 1.0))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                Text(memoDateRange(memo))
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if swipedMemoID == memo.id {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    swipedMemoID = nil
                }
            } else {
                childSheet = .memoEditor(.edit(memo))
            }
        }
    }

    @ViewBuilder
    private func eventCard(for event: YoteiEvent<EventData>) -> some View {
        let baseColor = colorForEvent(event)
        let isInteractive = event.data.kind == .event

        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(baseColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if event.data.kind == .shift {
                        Image(systemName: "briefcase.fill")
                            .font(.caption)
                            .foregroundStyle(textColor(on: baseColor).opacity(0.9))
                    }
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(textColor(on: baseColor))
                        .lineLimit(2)
                }

                Text(timeRange(for: event))
                    .font(.caption)
                    .foregroundStyle(textColor(on: baseColor).opacity(0.85))

                HStack(spacing: 6) {
                    if let calendarName = calendarName(for: event) {
                        Label(calendarName, systemImage: "calendar")
                            .font(.caption2)
                            .foregroundStyle(textColor(on: baseColor).opacity(0.85))
                            .labelStyle(.titleAndIcon)
                    }
                    if let preview = event.data.notesPreview {
                        Text(preview)
                            .font(.caption2)
                            .foregroundStyle(textColor(on: baseColor).opacity(0.75))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(baseColor.opacity(cardBackgroundAlpha))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if isInteractive { onSelectEvent(event.data.originId) }
        }
    }

    private func calendarName(for event: YoteiEvent<EventData>) -> String? {
        if event.data.kind == .shift {
            return "근무"
        }
        guard let id = event.data.ekCalendarIdentifier else { return nil }
        return calendarsById[id]?.title
    }

    private func colorForEvent(_ event: YoteiEvent<EventData>) -> Color {
        if let hex = event.data.colorHex, let color = Color(hex: hex) {
            return color
        }
        return .accentColor
    }

    private func textColor(on background: Color) -> Color {
        ContrastPalette.textColor(on: background, scheme: colorScheme)
    }

    private var cardBackgroundAlpha: Double {
        ContrastPalette.cardBackgroundAlpha(for: colorScheme)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private var currentHolidayName: String? {
        holidayName?(date)
    }

    @ViewBuilder
    private var headerTitle: some View {
        let isHoliday = currentHolidayName != nil
        VStack(spacing: 1) {
            HStack {
                Text(formattedDate)
                    .font(.headline)
                    .foregroundStyle(isHoliday ? HolidayPalette.red : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(shiftInfo?.dia?.typeName ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

            }
            
            
            
            if let name = currentHolidayName {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(HolidayPalette.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func timeRange(for event: YoteiEvent<EventData>) -> String {
        if event.isAllDay { return "종일" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.start)) - \(formatter.string(from: event.end))"
    }

    private func memoDateRange(_ memo: DateMemoDTO) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M월 d일"
        if calendar.isDate(memo.startDate, inSameDayAs: memo.endDate) {
            return "\(formatter.string(from: memo.startDate))"
        }
        return "\(formatter.string(from: memo.startDate)) – \(formatter.string(from: memo.endDate))"
    }
}

// MARK: - Apple Music 스타일 GroupBox

private struct MusicPlayerGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.headline)
                .foregroundColor(.secondary)
            configuration.content
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}
