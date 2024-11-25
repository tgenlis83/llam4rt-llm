/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import SwiftUI
import UniformTypeIdentifiers

import LLaMARunner

class RunnerHolder: ObservableObject {
  var runner: Runner?
  var llavaRunner: LLaVARunner?
}

extension UIImage {
  func resized(to newSize: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: newSize, format: format).image {
      _ in draw(in: CGRect(origin: .zero, size: newSize))
    }
  }

  func toRGBArray() -> [UInt8]? {
    guard let cgImage = self.cgImage else { return nil }

    let width = Int(cgImage.width), height = Int(cgImage.height)
    let totalPixels = width * height, bytesPerPixel = 4, bytesPerRow = bytesPerPixel * width
    var rgbValues = [UInt8](repeating: 0, count: totalPixels * 3)
    var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

    guard let context = CGContext(
      data: &pixelData, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ) else { return nil }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    for y in 0..<height {
      for x in 0..<width {
        let pixelIndex = (y * width + x) * bytesPerPixel
        let rgbIndex = y * width + x
        rgbValues[rgbIndex] = pixelData[pixelIndex]
        rgbValues[rgbIndex + totalPixels] = pixelData[pixelIndex + 1]
        rgbValues[rgbIndex + totalPixels * 2] = pixelData[pixelIndex + 2]
      }
    }
    return rgbValues
  }
}

struct ContentView: View {
  @State private var prompt = ""
  @State private var messages: [Message] = []
  @State private var showingLogs = false
  @State private var pickerType: PickerType?
  @State private var isGenerating = false
  @State private var shouldStopGenerating = false
  @State private var shouldStopShowingToken = false
  private let runnerQueue = DispatchQueue(label: "org.pytorch.executorch.llama")
  @StateObject private var runnerHolder = RunnerHolder()
  @StateObject private var resourceManager = ResourceManager()
  @StateObject private var resourceMonitor = ResourceMonitor()
  @StateObject private var logManager = LogManager()
  @StateObject private var memoryManager = MemoryManager()

  @State private var isImagePickerPresented = false
  @State private var selectedImage: UIImage?
  @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary

  @State private var showingSettings = false
  @State private var csvData = readCSV(filePath: Bundle.main.path(forResource: "dataset", ofType: "csv")!)

  enum PickerType {
    case model
    case tokenizer
  }

  private var placeholder: String {
    resourceManager.isModelValid ? resourceManager.isTokenizerValid ? "Prompt..." : "Select Tokenizer..." : "Select Model..."
  }

  private var title: String {
    resourceManager.isModelValid ? resourceManager.isTokenizerValid ? resourceManager.modelName : "Select Tokenizer..." : "Select Model..."
  }

  private var modelTitle: String {
    resourceManager.isModelValid ? resourceManager.modelName : "Select Model..."
  }

  private var tokenizerTitle: String {
    resourceManager.isTokenizerValid ? resourceManager.tokenizerName : "Select Tokenizer..."
  }

  private var isInputEnabled: Bool { resourceManager.isModelValid && resourceManager.isTokenizerValid }

  var body: some View {
    NavigationView {
      VStack {
        if showingSettings {
          VStack(spacing: 20) {
            Form {
              Section(header: Text("Model and Tokenizer")
                        .font(.headline)
                        .foregroundColor(.primary)) {
                Button(action: { pickerType = .model }) {
                  Label(resourceManager.modelName == "" ? modelTitle : resourceManager.modelName, systemImage: "doc")
                }
                Button(action: { pickerType = .tokenizer }) {
                  Label(resourceManager.tokenizerName == "" ? tokenizerTitle : resourceManager.tokenizerName, systemImage: "doc")
                }
              }
            }
          }
        }

        MessageListView(messages: $messages)
          .gesture(
            DragGesture().onChanged { value in
              if value.translation.height > 10 {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
              }
            }
          )
        HStack {
          Button(action: {
            imagePickerSourceType = .photoLibrary
            isImagePickerPresented = true
          }) {
            Image(systemName: "photo.on.rectangle")
              .resizable()
              .scaledToFit()
              .frame(width: 24, height: 24)
          }
          .background(Color.clear)
          .cornerRadius(8)

          Button(action: {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
              imagePickerSourceType = .camera
              isImagePickerPresented = true
            } else {
              print("Camera not available")
            }
          }) {
            Image(systemName: "camera")
              .resizable()
              .scaledToFit()
              .frame(width: 24, height: 24)
          }
          .background(Color.clear)
          .cornerRadius(8)

          TextField(placeholder, text: $prompt, axis: .vertical)
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(20)
            .lineLimit(1...10)
            .overlay(
              RoundedRectangle(cornerRadius: 20)
                .stroke(isInputEnabled ? Color.blue : Color.gray, lineWidth: 1)
            )
            .disabled(!isInputEnabled)

          Button(action: isGenerating ? stop : generate) {
            Image(systemName: isGenerating ? "stop.circle" : "arrowshape.up.circle.fill")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(height: 28)
          }
          .disabled(isGenerating ? shouldStopGenerating : (!isInputEnabled || prompt.isEmpty))
        }
        .padding([.leading, .trailing, .bottom], 10)
        .sheet(isPresented: $isImagePickerPresented, onDismiss: addSelectedImageMessage) {
          ImagePicker(selectedImage: $selectedImage, sourceType: imagePickerSourceType)
            .id(imagePickerSourceType.rawValue)
        }
      }
      .navigationBarTitle(title, displayMode: .inline)
      .navigationBarItems(
        leading:
          Button(action: {
            showingSettings.toggle()
          }) {
            Image(systemName: "gearshape")
              .imageScale(.large)
          },
        trailing:
          HStack {
            Menu {
              Section(header: Text("Memory")) {
                Text("Used: \(resourceMonitor.usedMemory) Mb")
                Text("Available: \(resourceMonitor.usedMemory) Mb")
              }
            } label: {
              Text("\(resourceMonitor.usedMemory) Mb")
            }
            .onAppear {
              resourceMonitor.start()
            }
            .onDisappear {
              resourceMonitor.stop()
            }
            Button(action: { showingLogs = true }) {
              Image(systemName: "list.bullet.rectangle")
            }
          }
      )
      .sheet(isPresented: $showingLogs) {
        NavigationView {
          LogView(logManager: logManager)
        }
      }
      .fileImporter(
        isPresented: Binding<Bool>(
          get: { pickerType != nil },
          set: { if !$0 { pickerType = nil } }
        ),
        allowedContentTypes: allowedContentTypes(),
        allowsMultipleSelection: false
      ) { [pickerType] result in
        handleFileImportResult(pickerType, result)
      }
      .onAppear {
        do {
          try resourceManager.createDirectoriesIfNeeded()
        } catch {
          withAnimation {
            messages.append(Message(type: .info, text: "Error creating content directories: \(error.localizedDescription)"))
          }
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }

  private func addSelectedImageMessage() {
    if let selectedImage {
      messages.append(Message(image: selectedImage))
    }
  }

  private func generate() {
    guard !prompt.isEmpty else { return }
    isGenerating = true
    shouldStopGenerating = false
    shouldStopShowingToken = false
    let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    let seq_len = 2048 // text: 256, vision: 768
    let modelPath = resourceManager.modelPath
    let tokenizerPath = resourceManager.tokenizerPath
    let useLlama = modelPath.lowercased().contains("llama")

    prompt = ""
    hideKeyboard()
    showingSettings = false

    messages.append(Message(text: text))
    messages.append(Message(type: useLlama ? .llamagenerated : .llavagenerated))

    // Fetch memory and add it to the prompt if available
      let memoryContext = memoryManager.getMemory().sorted(by: { $0.index < $1.index }).map { "User: \($0.key)\nAssistant: \($0.value)\n" }.joined(separator: "\n")
    let ragContext = createRAGInput(forString: text + memoryContext, csvEntries: csvData)
      
    // Define the special tokens
    let beginOfText = "<|begin_of_text|>"
    let endOfText = "<|end_of_text|>"
    let startHeader = "<|start_header_id|>"
    let endHeader = "<|end_header_id|>"
    let endOfTurn = "<|eot_id|>"

    // Define the system and user messages
    let systemMessage = """
    CONTEXT
    You are a helpful AI art assistant, called Llam4rt, the user will ask you questions about paintings. You have been tasked with helping us to answer the user input.
    You have been specifically trained on the Musée de l'Orangerie in Paris.
    
    DOCUMENTS
    You have access to the following documents which are meant to provide context as you answer the query:
    <documents>
    Musée de l'Orangerie:
    The Musée de l'Orangerie (English: Orangery Museum) is an art gallery of Impressionist and Post-Impressionist paintings located in the west corner of the Tuileries Garden next to the Place de la Concorde in Paris. The museum is most famous as the permanent home of eight large Water Lilies murals by Claude Monet, and also contains works by Paul Cézanne, Henri Matisse, Amedeo Modigliani, Pablo Picasso, Pierre-Auguste Renoir, Henri Rousseau, Alfred Sisley, Chaïm Soutine, Maurice Utrillo, and others.[1]
    
    User Oriented Information for Paintings:
    \(ragContext)
    </documents>
    
    HISTORY
    You have access to the conversation history, which is meant to provide even more context as you answer the query:
    <history>
    \(memoryContext)
    </history>
    """
    let userMessage = """
    \(text)
    """

    // Construct the prompt
    let prompt = """
    \(beginOfText)\(startHeader)system\(endHeader)
    \(systemMessage)\(endOfTurn)\(startHeader)user\(endHeader)
    \(userMessage)\(endOfTurn)\(startHeader)assistant\(endHeader)
    """
      
    print(prompt)

    runnerQueue.async {
      defer {
        DispatchQueue.main.async {
          isGenerating = false
          selectedImage = nil
        }
      }

      if useLlama {
        runnerHolder.runner = runnerHolder.runner ?? Runner(modelPath: modelPath, tokenizerPath: tokenizerPath)
      } else {
        runnerHolder.llavaRunner = runnerHolder.llavaRunner ?? LLaVARunner(modelPath: modelPath, tokenizerPath: tokenizerPath)
      }

      guard !shouldStopGenerating else { return }
      if useLlama {
        if let runner = runnerHolder.runner, !runner.isLoaded() {
          var error: Error?
          let startLoadTime = Date()
          do {
            try runner.load()
          } catch let loadError {
            error = loadError
          }

          let loadTime = Date().timeIntervalSince(startLoadTime)
          DispatchQueue.main.async {
            withAnimation {
              var message = messages.removeLast()
              message.type = .info
              if let error {
                message.text = "Model loading failed: error \((error as NSError).code)"
              } else {
                message.text = "Model loaded in \(String(format: "%.2f", loadTime)) s"
              }
              messages.append(message)
              if error == nil {
                messages.append(Message(type: .llamagenerated))
              }
            }
          }
          if error != nil {
            return
          }
        }
      } else {
        if let runner = runnerHolder.llavaRunner, !runner.isLoaded() {
          var error: Error?
          let startLoadTime = Date()
          do {
            try runner.load()
          } catch let loadError {
            error = loadError
          }

          let loadTime = Date().timeIntervalSince(startLoadTime)
          DispatchQueue.main.async {
            withAnimation {
              var message = messages.removeLast()
              message.type = .info
              if let error {
                message.text = "Model loading failed: error \((error as NSError).code)"
              } else {
                message.text = "Model loaded in \(String(format: "%.2f", loadTime)) s"
              }
              messages.append(message)
              if error == nil {
                messages.append(Message(type: .llavagenerated))
              }
            }
          }
          if error != nil {
            return
          }
        }
      }

      guard !shouldStopGenerating else {
        DispatchQueue.main.async {
          withAnimation {
            _ = messages.removeLast()
          }
        }
        return
      }
    var latestMsg: String = ""
      do {
        var tokens: [String] = []
        
        var rgbArray: [UInt8]?
        let MAX_WIDTH = 336.0
        var newHeight = 0.0
        var imageBuffer: UnsafeMutableRawPointer?

        if let img = selectedImage {
            let llava_prompt = "\(prompt) ASSISTANT"

          newHeight = MAX_WIDTH * img.size.height / img.size.width
          let resizedImage = img.resized(to: CGSize(width: MAX_WIDTH, height: newHeight))
          rgbArray = resizedImage.toRGBArray()
          imageBuffer = UnsafeMutableRawPointer(mutating: rgbArray)

          try runnerHolder.llavaRunner?.generate(imageBuffer!, width: MAX_WIDTH, height: newHeight, prompt: llava_prompt, sequenceLength: seq_len) { token in

            if token != llava_prompt {
              if token == "</s>" {
                shouldStopGenerating = true
                runnerHolder.llavaRunner?.stop()
              } else {
                tokens.append(token)
                if tokens.count > 2 {
                  let text = tokens.joined()
                  let count = tokens.count
                  tokens = []
                  DispatchQueue.main.async {
                    var message = messages.removeLast()
                    message.text += text
                    latestMsg = message.text
                    message.tokenCount += count
                    message.dateUpdated = Date()
                    messages.append(message)
                  }
                }
                if shouldStopGenerating {
                  runnerHolder.llavaRunner?.stop()
                }
              }
            }
          }
        } else {
          let llama3_prompt = prompt

            try runnerHolder.runner?.generate(llama3_prompt, sequenceLength: seq_len) { token in

            print(">>> token={\(token)}")
            if token != llama3_prompt {
              // hack to fix the issue that extension/llm/runner/text_token_generator.h
              // keeps generating after <|eot_id|>
              if token == "<|eot_id|>" {
                shouldStopShowingToken = true
              } else {
                  tokens.append(String(token.drop(while: { $0.isNewline })))
                if tokens.count > 2 {
                  let text = tokens.joined()
                  let count = tokens.count
                  tokens = []
                  DispatchQueue.main.async {
                    var message = messages.removeLast()
                    message.text += text
                    latestMsg = message.text
                    message.tokenCount += count
                    message.dateUpdated = Date()
                    messages.append(message)
                  }
                }
                if shouldStopGenerating {
                  runnerHolder.runner?.stop()
                }
              }
            }
          }
        }
        
        // Add prompt and response to memory
        DispatchQueue.main.async {
          memoryManager.addToMemory(prompt: text, response: latestMsg)
        }
      } catch {
        DispatchQueue.main.async {
          withAnimation {
            var message = messages.removeLast()
            message.type = .info
            message.text = "Text generation failed: error \((error as NSError).code)"
            messages.append(message)
          }
        }
      }
    }
  }

  private func stop() {
    shouldStopGenerating = true
  }

  private func allowedContentTypes() -> [UTType] {
    guard let pickerType else { return [] }
    switch pickerType {
    case .model:
      return [UTType(filenameExtension: "pte")].compactMap { $0 }
    case .tokenizer:
      return [UTType(filenameExtension: "bin"), UTType(filenameExtension: "model")].compactMap { $0 }
    }
  }

  private func handleFileImportResult(_ pickerType: PickerType?, _ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first, let pickerType else {
        withAnimation {
          messages.append(Message(type: .info, text: "Failed to select a file"))
        }
        return
      }
      runnerQueue.async {
        runnerHolder.runner = nil
        runnerHolder.llavaRunner = nil
      }
      switch pickerType {
      case .model:
        resourceManager.modelPath = url.path
      case .tokenizer:
        resourceManager.tokenizerPath = url.path
      }
    case .failure(let error):
      withAnimation {
        messages.append(Message(type: .info, text: "Failed to select a file: \(error.localizedDescription)"))
      }
    }
  }
}

extension View {
  func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }
}
