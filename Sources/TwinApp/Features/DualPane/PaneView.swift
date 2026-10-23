import SwiftUI
struct PaneView: View {
  @ObservedObject var viewModel: PaneViewModel
  var isActive: Bool
  var body: some View {
    VStack(spacing:0){
      HStack{
        Text(viewModel.currentURL.path).font(.caption).lineLimit(1).truncationMode(.middle)
        Spacer()
        Button(action:{viewModel.goUp()}){ Image(systemName:"arrow.up") }
      }.padding(6).background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
      Divider()
      List(viewModel.items, id: \.url, selection: $viewModel.selection){ item in
        HStack{
          Image(systemName: item.isDirectory ? "folder.fill" : "doc")
          Text(item.name)
          Spacer()
        }.onTapGesture(count:2){
          if item.isDirectory { viewModel.navigate(to: item.url) } else { NSWorkspace.shared.open(item.url) }
        }
      }.listStyle(.plain)
    }.border(isActive ? Color.accentColor : Color.clear, width: 1)
  }
}
