import SwiftUI

struct CounterPluginView: View {
  @Bindable var plugin: CounterPlugin
  
  var body: some View {
    VStack(spacing: 20) {
      Text("\(plugin.count)")
        .font(.system(size: 48, weight: .bold))
        .monospacedDigit()
      
      HStack(spacing: 12) {
        Button {
          plugin.decrement()
        } label: {
          Text("-")
            .font(.title)
            .frame(width: 60, height: 40)
        }
        .keyboardShortcut("d", modifiers: .control)
        
        Button {
          plugin.increment()
        } label: {
          Text("+")
            .font(.title)
            .frame(width: 60, height: 40)
        }
        .keyboardShortcut("a", modifiers: .control)
        
        Button {
          plugin.reset()
        } label: {
          Text("Reset")
            .frame(width: 80, height: 40)
        }
      }
    }
    .padding(30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  CounterPluginView(plugin: CounterPlugin.shared)
}
