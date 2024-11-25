//
//  Memory.swift
//  LLaMA
//
//  Created by Tom Genlis on 25/11/2024.
//

// Memory management for prompt history
import Foundation

class MemoryManager: ObservableObject {
    @Published var memory: [Memory] = []
    private var currentIndex: Int = 0
    
    struct Memory: Identifiable {
        let id = UUID()
        let index: Int
        let key: String
        let value: String
    }
    
    func addToMemory(prompt: String, response: String) {
        let memory = Memory(index: currentIndex, key: prompt, value: response)
        self.memory.append(memory)
        currentIndex += 1
    }
    
    func getMemory() -> [Memory] {
        return memory
    }
}
