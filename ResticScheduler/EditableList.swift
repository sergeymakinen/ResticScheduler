import Combine
import SwiftUI

struct EditableList: View {
    private struct Item: Identifiable, Equatable {
        let id = UUID()
        var value: String
    }

    private static let borderColor = Color(nsColor: .gridColor)

    @FocusState private var focused: UUID?
    @Namespace private var namespace
    @Environment(\.resetFocus) private var resetFocus
    @State private var browse = false
    @State private var appendedID: UUID?
    @State private var selection: UUID?
    @State private var items: [Item] = []

    private let title: any StringProtocol
    private let values: Binding<[String]>
    private let isBrowseable: Bool

    var body: some View {
        LabeledContent {
            ScrollViewReader { proxy in
                List($items, editActions: .move, selection: $selection) { item in
                    TextField("", text: item.value, onCommit: {
                        didChange()
                    })
                    .font(.callout)
                    .listRowInsets(.init())
                    .listRowSeparator(.hidden)
                    .focused($focused, equals: item.id)
                }
                .environment(\.defaultMinListRowHeight, 24)
                .frame(minHeight: 150)
                .onChange(of: appendedID) { _ in
                    withAnimation {
                        proxy.scrollTo(appendedID!)
                    }
                    focused = appendedID
                }
                .padding(.bottom, 24)
                .overlay(alignment: .bottom, content: {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                        HStack(spacing: 0) {
                            if isBrowseable {
                                Menu {
                                    Button("Browse…", action: { browse = true })
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
                            Button { remove() } label: {
                                Image(systemName: "minus")
                                    .frame(width: 24, height: 24)
                                    .padding(.top, -1)
                            }
                            .disabled(selection == nil)
                        }
                        .buttonStyle(.borderless)
                    }
                })
                .border(Self.borderColor)
                .animation(.easeInOut, value: items.count)
                .fileImporter(isPresented: $browse, allowedContentTypes: [.folder, .item], onCompletion: { result in
                    append(try! result.get().path(percentEncoded: false))
                })
            }
            .offset(x: 0, y: -12)
        } label: {
            Text(title)
                .offset(y: 3)
        }
        .onAppear {
            items = values.wrappedValue.map { value in
                Item(value: value)
            }
        }
    }

    init(_ title: any StringProtocol, values: Binding<[String]>, isBrowseable: Bool = true) {
        self.title = title
        self.values = values
        self.isBrowseable = isBrowseable
    }

    private func append(_ value: String) {
        resetFocus(in: namespace)
        let item = Item(value: value)
        items.append(item)
        selection = item.id
        appendedID = item.id
        didChange()
    }

    private func remove() {
        items.removeAll { $0.id == selection }
        didChange()
    }

    private func didChange() {
        let existingValues = values.wrappedValue
        let newValues = items.map(\.value).filter { !$0.isEmpty }
        if newValues.count != existingValues.count || newValues != existingValues {
            values.wrappedValue = newValues
        }
    }
}

#Preview {
    EditableList("title", values: .constant(["foo", "bar"]))
}
