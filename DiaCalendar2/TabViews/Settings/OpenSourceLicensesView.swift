import SwiftUI

struct OpenSourceLicensesView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    LicenseDetailView(library: .yotei)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Yotei")
                            .font(.body)
                        Text("MIT License")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                NavigationLink {
                    LicenseDetailView(library: .eventually)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Eventually")
                            .font(.body)
                        Text("MIT License")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("오픈소스 라이선스")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Detail

private struct LicenseDetailView: View {
    enum Library {
        case yotei
        case eventually
    }

    let library: Library

    var body: some View {
        ScrollView {
            Text(licenseText)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch library {
        case .yotei:      return "Yotei"
        case .eventually: return "Eventually"
        }
    }

    private var licenseText: String {
        switch library {
        case .yotei:      return Self.mitLicense
        case .eventually: return Self.mitLicense
        }
    }

    // MARK: - License texts

    private static let mitLicense = """
        MIT License

        Copyright (c) 2026 Mikalai Zmachynski

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
        """
}
