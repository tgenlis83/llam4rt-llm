import Foundation

// Define a structure to hold the CSV data
struct CSVEntry {
    let title: String
    let description: String
}

// Function to read CSV file and parse its content
func readCSV(filePath: String) -> [CSVEntry] {
    var result: [CSVEntry] = []
    
    do {
        let content = try String(contentsOfFile: filePath)
        let rows = content.components(separatedBy: "\n")
        
        for row in rows {
            // Split only the first occurrence of "," to avoid issues with commas in the description
            if let firstCommaIndex = row.range(of: ",") {
                let title = String(row[..<firstCommaIndex.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let description = String(row[firstCommaIndex.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let entry = CSVEntry(title: title, description: description)
                result.append(entry)
            }
        }
    } catch {
        print("Error reading CSV file: \(error)")
    }
    
    return result
}

// Function to create RAG (Retrieve and Generate) input for LLM using retrieved descriptions
func createRAGInput(forString input: String, csvEntries: [CSVEntry]) -> String {
    var ragInput: [String] = []
    
    // Iterate over each entry and find the matching titles in the input string
    for entry in csvEntries {
        if input.contains(entry.title) {
            let formattedEntry = "Title: \(entry.title)\nDescription: \(entry.description)"
            ragInput.append(formattedEntry)
        }
    }
    
    return ragInput.joined(separator: "\n\n")
}
