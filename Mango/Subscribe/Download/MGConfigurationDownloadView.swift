import SwiftUI

struct MGConfigurationDownloadView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject private var configurationListManager: MGConfigurationListManager
    
    @StateObject private var vm = MGConfigurationDownloadViewModel()
    
    @State private var isFileImporterPresented: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("请输入配置名称", text: $vm.name)
                } header: {
                    Text("名称")
                } footer: {
                    Text("配置名称可以不唯一，但不推荐")
                }
                Section {
                    HStack(spacing: 4) {
                        TextField(addressPrompt, text: $vm.urlString)
                            .disabled(isAddressTextFieldDisable)
                        switch vm.location {
                        case .local:
                            Button("浏览") {
                                isFileImporterPresented.toggle()
                            }
                            .fixedSize()
                        case .remote:
                            Picker(selection: $vm.format) {
                                ForEach(MGConfigurationFormat.allCases) { format in
                                    Text(format.rawValue.uppercased())
                                }
                            } label: {
                                EmptyView()
                            }
                            .fixedSize()
                        }
                    }
                } header: {
                    Text(addressTitle)
                } footer: {
                    Text("配置文件支持的格式：\(MGConfigurationFormat.allCases.map({ $0.rawValue.uppercased() }).joined(separator: "、"))")
                }
                Section {
                    Button {
                        Task(priority: .userInitiated) {
                            do {
                                try await vm.process()
                                await MainActor.run {
                                    configurationListManager.reload()
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    MGNotification.send(title:"", subtitle: "", body: error.localizedDescription)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(buttonTitle)
                            Spacer()
                        }
                    }
                    .disabled(isButtonDisbale)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(vm.isProcessing)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker(selection: $vm.location) {
                        ForEach(MGConfigurationLocation.allCases) { location in
                            Text(location.description)
                        }
                    } label: {
                        EmptyView()
                    }
                    .fixedSize()
                    .pickerStyle(.segmented)
                }
            }
            .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: MGConfigurationFormat.allCases.map(\.uniformTypeType)) { result in
                switch result {
                case .success(let success):
                    vm.urlString = success.path(percentEncoded: false)
                    if vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        vm.name = success.deletingPathExtension().lastPathComponent
                    }
                case .failure(let failure):
                    MGNotification.send(title: "", subtitle: "", body: failure.localizedDescription)
                }
            }
            .onChange(of: vm.location) { _ in
                vm.urlString = ""
            }
            .toolbar {
                if vm.isProcessing {
                    ProgressView()
                }
            }
        }
        .disabled(vm.isProcessing)
    }
    
    private var addressTitle: String {
        switch vm.location {
        case .local:
            return "位置"
        case .remote:
            return "地址"
        }
    }
    
    private var addressPrompt: String {
        switch vm.location {
        case .local:
            return "请选择本地文件"
        case .remote:
            return "请输入配置文件地址"
        }
    }
    
    private var isAddressTextFieldDisable: Bool {
        switch vm.location {
        case .local:
            return true
        case .remote:
            return false
        }
    }
    
    private var buttonTitle: String {
        switch vm.location {
        case .local:
            return "导入"
        case .remote:
            return "下载"
        }
    }
    
    private var isButtonDisbale: Bool {
        guard !vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        switch vm.location {
        case .local:
            return vm.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .remote:
            return URL(string: vm.urlString.trimmingCharacters(in: .whitespacesAndNewlines)) == nil
        }
    }
}
