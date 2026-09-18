import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NoteStore

    @State private var isPresentingAddAlert = false
    @State private var newGroupName = ""
    @State private var selectedGroup: NoteGroup?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.fileURL == nil {
                    emptyStateView
                } else {
                    listView
                    Divider()
                    passwordBar
                }
            }
            .navigationTitle(store.fileURL?.deletingPathExtension().lastPathComponent ?? "NoteSweeker")
            .toolbar {
                ToolbarItemGroup {
                    Button("Open File", systemImage: "folder") {
                        store.openFile()
                    }
                    Button("New File", systemImage: "doc.badge.plus") {
                        store.newFile()
                    }
                    if store.fileURL != nil {
                        Button("Add Note", systemImage: "plus") {
                            newGroupName = ""
                            isPresentingAddAlert = true
                        }
                    }
                    Menu {
                        ForEach(NoteFontSize.allCases) { size in
                            Button {
                                store.fontSize = size.rawValue
                            } label: {
                                if store.fontSize == size.rawValue {
                                    Label(size.label, systemImage: "checkmark")
                                } else {
                                    Text(size.label)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "textformat.size")
                    }
                    .help("Font Size")
                    Menu {
                        ForEach(NoteAccentColor.allCases) { colorOption in
                            Button {
                                store.accentColor = colorOption
                            } label: {
                                if store.accentColor == colorOption {
                                    Label(colorOption.label, systemImage: "checkmark")
                                } else {
                                    Text(colorOption.label)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "paintpalette")
                    }
                    .help("List Color")
                }
            }
            .alert("New Note", isPresented: $isPresentingAddAlert) {
                TextField("Name", text: $newGroupName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    store.addNoteGroup(named: newGroupName)
                }
            } message: {
                Text("Enter a name for the new note.")
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
            .sheet(item: $selectedGroup) { group in
                NoteDetailView(groupID: group.id)
                    .environmentObject(store)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No file open")
                .font(.title2)
            Text("Open an existing notes file or create a new one to get started.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Open File") { store.openFile() }
                Button("New File") { store.newFile() }
                if store.hasLastFile {
                    Button("Open Last File") { store.openLastFile() }
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: 400)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        List {
            ForEach(Array(store.noteGroups.enumerated()), id: \.element.id) { index, group in
                HStack {
                    Button {
                        selectedGroup = group
                    } label: {
                        HStack {
                            Text(group.noteName)
                                .font(.system(size: store.fontSize))
                            Spacer()
                            Text("\(group.contents.count)")
                                .font(.system(size: store.fontSize))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        store.removeNoteGroup(group)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                .listRowBackground(
                    index.isMultiple(of: 2) ? store.accentColor.baseRowColor : store.accentColor.alternateRowColor
                )
            }
        }
    }

    private var passwordBar: some View {
        HStack {
            Image(systemName: "lock")
                .foregroundStyle(.secondary)
            SecureField("Password for encrypted values", text: $store.password)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { isPresented in
                if !isPresented { store.errorMessage = nil }
            }
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(NoteStore())
}
