import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NoteStore

    @State private var isPresentingAddAlert = false
    @State private var newGroupName = ""
    @State private var selectedGroup: NoteGroup?

    var body: some View {
        NavigationStack {
            Group {
                if store.fileURL == nil {
                    emptyStateView
                } else {
                    listView
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
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: 400)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        List {
            ForEach(store.noteGroups) { group in
                HStack {
                    Button {
                        selectedGroup = group
                    } label: {
                        HStack {
                            Text(group.noteName)
                            Spacer()
                            Text("\(group.contents.count)")
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
            }
        }
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
