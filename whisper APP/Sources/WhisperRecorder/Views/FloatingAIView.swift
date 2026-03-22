import SwiftUI

struct FloatingAIView: View {
    @ObservedObject var groqService = GroqChatService.shared
    @EnvironmentObject var manager: TranscriptionManager
    @State private var isExpanded = false
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var inputText = ""
    @AppStorage("app_theme") private var currentTheme: String = AppTheme.cyberpunk.rawValue
    
    var theme: AppTheme {
        AppTheme(rawValue: currentTheme) ?? .dark
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                // Dimmed background when expanded
                if isExpanded {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) {
                                isExpanded = false
                            }
                        }
                }
                
                // Content
                if isExpanded {
                    expandedView
                        .frame(width: 350, height: 500)
                        .background(theme.backgroundColor)
                        .cornerRadius(20)
                        .shadow(radius: 20)
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                        .transition(.scale(scale: 0.1, anchor: .bottomTrailing).combined(with: .opacity))
                } else {
                    collapsedView
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height - value.translation.height // Inverted because bottom alignment
                                    )
                                }
                                .onEnded { value in
                                    lastOffset = offset
                                }
                        )
                        .padding(.bottom, 20) // Default padding
                        .padding(.trailing, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
    
    var collapsedView: some View {
        Button(action: {
            withAnimation(.spring()) {
                isExpanded = true
            }
        }) {
            ZStack {
                Circle()
                    .fill(theme.accentColor)
                    .frame(width: 60, height: 60)
                    .shadow(radius: 5)
                
                if groqService.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    var expandedView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(theme.accentColor)
                Text("Assistant IA")
                    .font(.headline)
                    .foregroundColor(theme.textColor)
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        isExpanded = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondaryTextColor)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(theme.secondaryBackgroundColor)
            
            // Chat List
            ChatListView()
                .padding(.bottom, 8)
            
            // Input Area
            HStack(spacing: 8) {
                TextField("Demandez quelque chose...", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(theme.secondaryBackgroundColor.opacity(0.5))
                    .cornerRadius(20)
                    .onSubmit {
                        sendMessage()
                    }
                
                if groqService.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(inputText.isEmpty ? theme.secondaryTextColor : theme.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty)
                }
            }
            .padding()
            .background(theme.secondaryBackgroundColor)
        }
    }
    
    func sendMessage() {
        guard !inputText.isEmpty else { return }
        let message = inputText
        inputText = ""
        
        Task {
            await groqService.sendMessage(message)
        }
    }
}

// Helper struct for the view
struct FloatingChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let toolCalls: [[String: Any]]?
}

// A simplified version of ChatListView for the floating head
struct ChatListView: View {
    @ObservedObject var groqService = GroqChatService.shared
    @AppStorage("app_theme") private var currentTheme: String = AppTheme.cyberpunk.rawValue
    
    var theme: AppTheme {
        AppTheme(rawValue: currentTheme) ?? .dark
    }
    
    var messages: [FloatingChatMessage] {
        if let sessionId = groqService.currentSessionId {
            let dbMessages = DatabaseManager.shared.getMessages(sessionId: sessionId)
            return dbMessages.map { msg in
                FloatingChatMessage(role: msg.role, content: msg.content, toolCalls: msg.toolCalls)
            }
        }
        return []
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        FloatingMessageBubble(message: message, theme: theme)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                if let lastId = messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// Reusing MessageBubble logic but simplified
struct FloatingMessageBubble: View {
    let message: FloatingChatMessage
    let theme: AppTheme
    
    var isUser: Bool {
        message.role == "user"
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(10)
                    .background(isUser ? theme.accentColor : theme.secondaryBackgroundColor)
                    .foregroundColor(isUser ? .white : theme.textColor)
                    .cornerRadius(12)
                    .font(.system(size: 14))
                
                if let toolCalls = message.toolCalls {
                    ForEach(0..<toolCalls.count, id: \.self) { index in
                        let tool = toolCalls[index]
                        if let function = tool["function"] as? [String: Any],
                           let name = function["name"] as? String {
                            Text("🛠️ \(name)")
                                .font(.caption2)
                                .foregroundColor(theme.secondaryTextColor)
                        }
                    }
                }
            }
            
            if !isUser { Spacer() }
        }
    }
}
