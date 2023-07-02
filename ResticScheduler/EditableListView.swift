import Combine
import SwiftUI

struct EditableListView: View {
  private static let borderColor = Color(nsColor: NSColor.gridColor)

  @ObservedObject private var editableList: EditableList

  @FocusState private var focused: Int?
  @Namespace private var namespace
  @Environment(\.resetFocus) private var resetFocus
  @State private var appendedID: Int?
  private var browseable: Bool

  var body: some View {
    ScrollViewReader { proxy in
      List($editableList.list, selection: $editableList.selection) { item in
        TextField("", text: item.value)
          .padding(.leading, -8)
          .listRowInsets(.init())
          .focused($focused, equals: item.id)
      }
      .environment(\.defaultMinListRowHeight, 24)
      .frame(minHeight: 150)
      .onChange(of: appendedID) { _ in
        withAnimation {
          proxy.scrollTo(appendedID!)
        }
        if editableList.list.first(where: { item in item.id == appendedID })?.value == "" {
          focused = appendedID
        }
      }
      .padding(.bottom, 24)
      .overlay(alignment: .bottom, content: {
        VStack(alignment: .leading, spacing: 0) {
          Divider()
          HStack(spacing: 0) {
            if browseable {
              Menu {
                Button("Browse…", action: { editableList.browse = true })
              } label: {
                Image(systemName: "plus")
                  .frame(width: 24, height: 24)
              } primaryAction: {
                append("")
              }
              .frame(width: 36, height: 24)
              .padding(.trailing, 4)
            } else {
              Button { append("") } label: {
                Image(systemName: "plus")
                  .frame(width: 24, height: 24)
                  .padding(.top, -1)
              }
            }
            Divider().frame(height: 16)
            Button { editableList.remove() } label: {
              Image(systemName: "minus")
                .frame(width: 24, height: 24)
                .padding(.top, -1)
            }
            .disabled(editableList.selection == nil)
          }
          .buttonStyle(.borderless)
        }
      })
      .border(Self.borderColor)
      .animation(.easeInOut, value: editableList.list.count)
      .fileImporter(isPresented: $editableList.browse, allowedContentTypes: [.folder, .item], onCompletion: { result in
        append(try! result.get().path(percentEncoded: false))
      })
    }
  }

  init(_ data: Binding<[String]>, browseable: Bool = true) {
    editableList = EditableList(data)
    self.browseable = browseable
  }

  private func append(_ value: String) {
    resetFocus(in: namespace)
    editableList.append(value)
    appendedID = editableList.selection
  }
}

struct FileListView_Previews: PreviewProvider {
  static var previews: some View {
    EditableListView(.constant(["foo", "bar"]))
  }
}
