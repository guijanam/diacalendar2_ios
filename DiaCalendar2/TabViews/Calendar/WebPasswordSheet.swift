import SwiftUI

struct WebPasswordSheet: View {
    let officeName: String
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var showError = false

    private var correctPassword: String? {
        OfficeWebURLMap.entry(for: officeName)?.password
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("비밀번호", text: $input)
                        .onSubmit { verify() }
                } header: {
                    Text("\(officeName) 웹사이트 접근")
                } footer: {
                    if showError {
                        Text("비밀번호가 올바르지 않습니다.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("확인") { verify() }
                        .frame(maxWidth: .infinity)
                        .disabled(input.isEmpty)
                }
            }
            .navigationTitle("비밀번호 입력")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    private func verify() {
        guard input == correctPassword else {
            showError = true
            input = ""
            return
        }
        WebPasswordStore.markAuthenticated(for: officeName)
        dismiss()
        onSuccess()
    }
}
